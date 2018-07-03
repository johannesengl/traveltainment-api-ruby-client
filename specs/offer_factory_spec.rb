require 'rails_helper'

RSpec.describe TtApi::OfferFactory do
  include Helpers

  let(:offer_factory) { TtApi::OfferFactory.new }

  it 'should be declared' do
    expect(TtApi::OfferFactory).to be_a Class
  end

  describe '#process_offer_items', vcr: { cassette_name: 'availability_check_mixed' } do

    before(:all) do
      set_average_price_for_set
    end

    after(:all) do
      clean_up_average
    end

    let(:offer_set) { TtApi::OfferSet.new(Helpers::DEPARTURE_AIRPORT_IATA_CODE, Helpers::HOTEL_IFF_CODE, Helpers::NIGHTS) }
    let(:offer_items) { offer_set.fetch_offers }

    it 'creates the cheapest offer for average prices' do
      offer_factory.process_offer_items(offer_items)
      cheapest_id = offer_items.first.tt_id
      expect(Offer.created_at_days_ago(0).find_by(tt_id: cheapest_id)).not_to be(nil)
    end

    it 'creates no offer because offers exceed max price' do
      offer_items.first.price = 3000
      offer_factory.process_offer_items(offer_items)
      expect(Offer.count).to be(0)
    end

    it 'creates all available offers' do
      offer_factory.process_offer_items(offer_items)
      all_are_created = offer_items.select(&:available).all? { |offer_item| Offer.created_at_days_ago(0).find_by(tt_id: offer_item.tt_id) }
      expect(all_are_created).to be(true)
    end

    it 'creates only available offers if cheap and direct_flight', vcr: { cassette_name: 'availability_check_raised_prices' } do
      offer_factory.process_offer_items(offer_items)
      tt_ids = offer_items.map(&:tt_id)
      offers = Offer.created_at_days_ago(0).where(tt_id: tt_ids, available: true)
      all_are_available = offers.all? {|offer| offer.direct_flight && offer.cheap? }
      expect(all_are_available).to be(true)
    end

    it 'creates the correct flights' do
      offer_factory.process_offer_items(offer_items)

      Offer.created_at_days_ago(0).available.direct_flight.each do |offer|
        expect(offer.outbound_flight.departure_airport.iata_code).to eq("TXL")
        expect(offer.outbound_flight.destination_airport.iata_code).to eq("PMI")
        expect(offer.inbound_flight.destination_airport.iata_code).to eq("TXL")
        expect(offer.inbound_flight.departure_airport.iata_code).to eq("PMI")
      end
    end

    it 'parses special journey attributes correctly' do
      offer_factory.process_offer_items(offer_items)

      Offer.created_at_days_ago(0).available.direct_flight.each do |offer|
        expect(offer.railfly).to be(true)
        expect(offer.transfer).to be(false)
      end
    end

  end

end
