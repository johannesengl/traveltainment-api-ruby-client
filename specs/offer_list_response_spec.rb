require 'rails_helper'

RSpec.describe TtApi::OfferListResponse do

  let(:departure_airport_iata_code) { 'TXL' }
  let(:hotel_iff_code) { 55050 }
  let(:nights) { 2 }

  let(:offer_list_response) { TtApi::Client.search_engine_offer_list(departure_airport_iata_code, hotel_iff_code, nights) }

  it 'should be declared' do
    expect(TtApi::OfferListResponse).to be_a Class
  end

  describe '#cheapest_offer_items' do
    let(:cheapest_offer_items) { offer_list_response.cheapest_offer_items }

    it 'returns an array with max items', vcr: { cassette_name: 'offer_list_with_cheap' } do
      expect(cheapest_offer_items.length).to be <= 10
    end

    it 'does not include alternatives', vcr: { cassette_name: 'offer_list_with_cheap_only_alternatives' } do
      none_is_alternative = cheapest_offer_items.none? {|o| o[:alternative]}
      expect(none_is_alternative).to be(true)

      all_have_highest_weightages = cheapest_offer_items.all? {|o| o[:weightage] == "100"}
      expect(all_have_highest_weightages).to be(true)
    end

    it 'includes at least one breakfast offer', vcr: { cassette_name: 'offer_list_with_cheap_with_only_expensive_breakfast' } do
      includes_a_breakfast_offer = cheapest_offer_items.any? {|o| o[:package][:accommodation][:meal][:meal] == "BREAKFAST" }
      expect(includes_a_breakfast_offer).to be(true)
    end
  end
end
