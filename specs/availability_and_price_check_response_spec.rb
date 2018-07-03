require 'rails_helper'

UPDATED_PRICE = 235.00
CARRIER_CODE = "AB"
OUTBOUND_FLIGHT_NUMBER = '7762'
INBOUND_FLIGHT_NUMBER = '7763'

RSpec.describe TtApi::AvailabilityAndPriceCheckResponse do

  let(:tt_id) { '074_0597F00400031031_0' }

  let(:response) { TtApi::Client.availability_and_price_check(tt_id) }

  it 'should be declared' do
    expect(TtApi::AvailabilityAndPriceCheckResponse).to be_a Class
  end

  context 'when available', vcr: { cassette_name: 'availability_check_available' } do

    describe '#available?' do

      it 'returns true' do
        expect(response.available?).to be(true)
      end

    end

    describe '#is_locked_operator?' do

      it 'returns false' do
        expect(response.is_locked_operator?).to be(false)
      end

    end

    describe '#direct_flight?' do

      it 'returns true' do
        expect(response.direct_flight?).to be(true)
      end

    end

    describe '#flight_assured?' do

      it 'returns true' do
        expect(response.direct_flight?).to be(true)
      end

    end

    describe '#flights' do

      it 'returns correct outbound flight data' do
        expect(response.flights[:outbound_flight][:airline][:carrier_code]).to eq(CARRIER_CODE)
        expect(response.flights[:outbound_flight][:flight_number]).to eq(OUTBOUND_FLIGHT_NUMBER)
      end

      it 'returns correct inbound flight data' do
        expect(response.flights[:inbound_flight][:airline][:carrier_code]).to eq(CARRIER_CODE)
        expect(response.flights[:inbound_flight][:flight_number]).to eq(INBOUND_FLIGHT_NUMBER)
      end

    end

    describe '#price' do

      it 'returns the updated price' do
        expect(response.price).to be(UPDATED_PRICE)
      end

    end

  end

  context 'when flight booked out', vcr: { cassette_name: 'availability_check_flight_booked_out' } do

    describe '#available?' do

      it 'returns false' do
        expect(response.available?).to be(false)
      end

    end

    describe '#is_locked_operator?' do

      it 'returns false' do
        expect(response.is_locked_operator?).to be(false)
      end

    end

    describe '#direct_flight?' do

      it 'returns false' do
        expect(response.direct_flight?).to be(false)
      end

    end

    describe '#flight_assured?' do

      it 'returns false' do
        expect(response.direct_flight?).to be(false)
      end

    end

    describe '#flights' do

      it 'returns nil' do
        expect(response.flights).to be(nil)
      end

    end

    describe '#price' do

      it 'returns nil' do
        expect(response.price).to be(nil)
      end

    end

  end

  context 'when locked tour operator', vcr: { cassette_name: 'availability_check_error_while_processing' } do

    describe '#is_locked_operator?' do

      it 'returns true' do
        expect(response.is_locked_operator?).to be(true)
      end

    end

  end

  context 'when no BookOnFix possible', vcr: { cassette_name: 'availability_check_available_not_book_on_fix' } do

    describe '#available?' do

      it 'returns false' do
        expect(response.available?).to be(false)
      end

    end

  end

end
