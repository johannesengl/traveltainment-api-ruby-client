require 'rails_helper'

RSpec.describe TtApi::OfferSet do
  include Helpers
  let(:offer_set) { TtApi::OfferSet.new(Helpers::DEPARTURE_AIRPORT_IATA_CODE, Helpers::HOTEL_IFF_CODE, Helpers::NIGHTS) }

  before(:all) do
    set_average_price_for_set
    Hotel.update_all(published: true)
  end

  after(:all) do
    clean_up_average
  end

  it 'should be declared' do
    expect(TtApi::OfferSet).to be_a Class
  end

  describe '#fetch_offers', vcr: { cassette_name: 'availability_check_mixed' } do

    let(:offers) { offer_set.fetch_offers }

    it 'returns items of TtApi::OfferItem' do
      all_are_offer_items = offers.all? {|o| o.is_a?(TtApi::OfferItem) }
      expect(all_are_offer_items).to be(true)
    end

    it 'returns alternative offers with discount at least as specified for alternatives' do
      available_offers = offers.select(&:available)
      all_enough_discount = available_offers.all? { |offer| offer.discount >= Offer::REQUIRED_DISCOUNT_FOR_ALTERNATIVE }
      expect(all_enough_discount).to be(true)
    end

    it 'returns at least one cheap offer if any available' do
      available_offers = offers.select(&:available)
      any_cheap_offers = available_offers.any?(&:cheap?)
      expect(any_cheap_offers).to be(true)
    end

    context 'with 3 available offers, 3 cheap' do

      it 'returns 3 cheap offers' do
        cheap_offers = offers.select(&:cheap?)
        expect(cheap_offers.count).to be(3)
      end

      it 'returns 3 available offers' do
        available_offers = offers.select(&:available)
        expect(available_offers.count).to be(3)
      end

    end

  end

end
