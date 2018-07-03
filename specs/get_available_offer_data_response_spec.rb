require 'rails_helper'

RSpec.describe TtApi::GetAvailableOfferDataResponse do

  let(:session_id) { '6367c972-e0c1-43df-9192-c974b5e9d2f0' }
  let(:response) { TtApi::Client.get_available_offer_data(session_id) }

  it 'should be declared' do
    expect(TtApi::GetAvailableOfferDataResponse).to be_a Class
  end

  context 'when valid session id', vcr: { cassette_name: 'get_available_offer_data_session_id_valid' } do

    describe '#success?' do
      it 'returns true' do
        expect(response.success?).to be(true)
      end
    end

    describe '#cautions, #booking_types, #payment_data, #room' do
      it 'returns valid booking data' do
        expect(response.cautions).to be_a(String)
        expect(response.room).to be_a(String)
        expect(response.booking_types).to be_a(Array)
        expect(response.payment_data).to be_a(Array)
      end
    end

  end

  context 'when expired session id', vcr: { cassette_name: 'get_available_offer_data_session_id_expired' } do
    describe '#success?' do
      it 'returns false' do
        expect(response.success?).to be(false)
      end
    end

    describe '#cautions, #booking_types, #payment_data' do
      it 'returns empty booking data' do
        expect(response.cautions).to be(nil)
        expect(response.room).to be(nil)
        expect(response.booking_types).to be(nil)
        expect(response.payment_data).to be(nil)
      end
    end
  end

end
