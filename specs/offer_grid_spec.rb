require 'rails_helper'

RSpec.describe TtApi::OfferGrid do
  include Helpers
  let(:offer_grid) { TtApi::OfferGrid.new(Helpers::DEPARTURE_AIRPORT_IATA_CODE, Helpers::HOTEL_IFF_CODE, Helpers::NIGHTS_MIN, Helpers::NIGHTS_MAX) }

  before(:all) do
    Hotel.update_all(published: true)
    set_average_price_for_set
  end

  after(:all) do
    clean_up_average
  end

  it 'should be declared' do
    expect(TtApi::OfferGrid).to be_a Class
  end

  describe '#fetch_offers', vcr: { cassette_name: 'offer_list_calender_offers' } do

    let(:grid_data) { offer_grid.fetch_offers(Date.current, Date.current + 84) }

    it 'returns a hash' do
      expect(grid_data).to be_a(Hash)
    end

    it 'returns a hash with date keys' do
      all_keys_are_dates = grid_data.keys.all? {|k| k.is_a?(Date)}
      expect(all_keys_are_dates).to be(true)
    end

    it 'returns hash with array of TtApi::OfferItem as value' do
      all_values_are_arrays_of_offer_items = grid_data[grid_data.keys[3]].all? {|o| o.is_a?(TtApi::OfferItem)}
      expect(all_values_are_arrays_of_offer_items).to be(true)
    end

    it 'returns array of hashes with array of TtApi::OfferItem as value with size 3 and 2, 3 and 4 nights' do
      first_is_two_nights = grid_data[grid_data.keys[3]][0].nights == 2
      second_is_three_nights = grid_data[grid_data.keys[3]][1].nights == 3
      third_is_four_nights = grid_data[grid_data.keys[3]][2].nights == 4
      expect(first_is_two_nights && second_is_three_nights && third_is_four_nights).to be(true)
    end

  end

end
