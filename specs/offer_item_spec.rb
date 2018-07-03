require 'rails_helper'

UPDATED_PRICE = 235.00
TOUR_OPERATOR = "LTUR"
DEPARTURE_AIRPORT_IATA_CODE = 'TXL'
HOTEL_IFF_CODE = 55050
NIGHTS = 2
CATERING = "BREAKFAST"

RSpec.describe TtApi::OfferItem do
  include Helpers

  before(:each) do
    TtApi::LockedTourOperators.reset
    @hotel = Hotel.find_by(iff_code: HOTEL_IFF_CODE) || create(:hotel, iff_code: HOTEL_IFF_CODE)
  end

  let(:offer_item) do
    TtApi::OfferItem.create_from_offer_list_data({
      offer_id: rand(1000),
      price_information: {
        original_price: 300
      },
      travel_duration: NIGHTS,
      tour_operator: {
        code: TOUR_OPERATOR
      },
      departure_date: Date.today + 1.month,
      special_journey_attributes: "RAILANDFLY",
      package: {
        accommodation: {
          meal: {
            meal: CATERING
          }
        }
      }
    }, HOTEL_IFF_CODE, DEPARTURE_AIRPORT_IATA_CODE)
  end

  it 'should be declared' do
    expect(TtApi::OfferItem).to be_a Class
  end

  describe '.create_from_data' do
    it 'should not be available' do
      expect(offer_item.available).to be(false)
    end
  end

  describe '#cheap?', vcr: { cassette_name: 'googlemaps/set_geo_by_place_id' } do

    before(:all) do
      set_average_price_for_set
    end

    after(:all) do
      clean_up_average
    end

    let(:cheap_offer_item) do
      cheap_offer_item = offer_item.dup
      cheap_offer_item.price = 200
      cheap_offer_item
    end

    let(:not_cheap_offer_item) do
      not_cheap_offer_item = offer_item.dup
      not_cheap_offer_item.price = 400
      not_cheap_offer_item
    end

    let(:not_cheap_offer_item_due_to_absolute_price) do
      not_cheap_offer_item_due_to_absolute_price = offer_item.dup
      not_cheap_offer_item_due_to_absolute_price.nights = 1
      not_cheap_offer_item_due_to_absolute_price.price = 260
      not_cheap_offer_item_due_to_absolute_price
    end

    context 'when custom discount for offer set exists' do

      it 'returns false for not cheap enough OfferItem' do
        OfferSet.create(hotel: Hotel.find_by(iff_code: cheap_offer_item.hotel_iff_code),
          departure_airport: Airport.find_by(iata_code: cheap_offer_item.departure_airport_iata_code),
          required_discount: 50)

        expect(cheap_offer_item.cheap?).to be(false)
      end

    end

    context 'when no custom discount for offer set exists' do

      it 'returns true for cheap OfferItem' do
        expect(cheap_offer_item.cheap?).to be(true)
      end

    end

    it 'returns false for not cheap OfferItem' do
      expect(not_cheap_offer_item.cheap?).to be(false)
    end

    it 'returns false for not cheap OfferItem if discount is cheap but absolute price not' do
      expect(not_cheap_offer_item_due_to_absolute_price.cheap?).to be(false)
    end

  end

  context 'when available', vcr: { cassette_name: 'availability_check_available' } do

    describe '#fetch_price_and_availability' do

      it 'updates the price' do
        offer_item.fetch_price_and_availability
        expect(offer_item.price).to be(UPDATED_PRICE)
      end

      it 'appends the flight' do
        offer_item.fetch_price_and_availability
        expect(offer_item.flights).not_to be(nil)
      end

      it 'updates the availability' do
        offer_item.fetch_price_and_availability
        expect(offer_item.available).to be(true)
      end

      it 'does not add the tour operator to the locked list' do
        offer_item.fetch_price_and_availability
        expect(TtApi::LockedTourOperators.include?(TOUR_OPERATOR)).to be(false)
      end

    end

  end

  context 'when new tour operator error', vcr: { cassette_name: 'availability_check_error_while_processing' } do

    describe '#fetch_price_and_availability' do

      it 'adds the tour operator to the locked list' do
        offer_item.fetch_price_and_availability
        expect(TtApi::LockedTourOperators.include?(TOUR_OPERATOR)).to be(true)
      end

    end

  end

  context 'when already locked tour operator', vcr: { cassette_name: 'availability_check_error_while_processing' } do

    before(:each) { TtApi::LockedTourOperators.add(TOUR_OPERATOR) }

    describe '#fetch_price_and_availability' do

      it 'does not send a request' do
        skip # we are sending requests even if the tour operators are locked at the moment
        offer_item.fetch_price_and_availability
        expect(offer_item.status).to be(nil)
      end

    end

  end

  context 'when hotel not published' do

    before(:each) { @hotel.update(published: false) }

    describe '#fetch_price_and_availability' do

      it 'does not send a request' do
        offer_item.fetch_price_and_availability
        expect(offer_item.status).to be(nil)
      end

    end

  end

end
