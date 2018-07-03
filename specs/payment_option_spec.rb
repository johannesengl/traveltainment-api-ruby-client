require 'rails_helper'

RSpec.describe TtApi::PaymentOption do

  let(:session_id) { '0581ad2d-5626-43a9-910b-ef1d53942e40' }
  let(:tt_booking_offer_data) { TtApi::Booking.get_available_offer_data(session_id)}

  context 'when valid session id and offer data payment options relative and absolute' do
    describe '#compose_payment_options' do
      it 'returns an array of payment options with an hash attribute surgarge', vcr: { cassette_name: 'get_available_offer_data_session_id_valid_payment_option_surgarge_absolute' } do
        expect(tt_booking_offer_data.payment_options).to be_a(Array)
        expect(tt_booking_offer_data.payment_options.first.surcharge[:absolute]).to be_a(Float)
        expect(tt_booking_offer_data.payment_options[1].surcharge[:relative]).to be_a(Float)
      end
    end
  end

end
