require 'rails_helper'

RSpec.describe TtApi::TourOperator do

  let(:tour_operator_code) { 'JTTTR' }
  let(:departure_date) { '2015-12-01--k' }
  let(:terms_and_conditions) {TtApi::TourOperator.fetch_terms_and_conditions(tour_operator_code, departure_date)}

  it 'should be declared' do
    expect(TtApi::TourOperator).to be_a Class
  end

  context 'valid tour_operator_code and departure_date', vcr: { cassette_name: 'terms_and_conditions_valid'} do

    describe '#fetch_terms_and_conditions' do

      it 'returns a string' do
        expect(terms_and_conditions).to be_a(String)
      end

    end

  end

  context 'invalid tour_operator_code and departure_date', vcr: { cassette_name: 'terms_and_conditions_invalid'} do

    describe '#fetch_terms_and_conditions' do

      it 'returns nil' do
        expect(terms_and_conditions).to be(nil)
      end

    end

  end

end
