require 'rails_helper'

RSpec.describe TtApi::Booking do

  let(:session_id) { 'xxx' }
  let(:tt_booking_offer_data) { TtApi::Booking.get_available_offer_data(session_id)}

  let(:payment_token) { 'f8ht7KbcbyfAmGHeu0_VPg' }
  let(:booking) { create(:booking) }
  let(:complete_booking) {create(:complete_booking)}
  let(:tt_booking_shopping_card_data) { TtApi::Booking.send_to_tt(complete_booking, payment_token)}


  it 'should be declared' do
    expect(TtApi::Booking).to be_a Class
  end

  context 'when valid session id' do
  	describe '#compose_payment_options' do
  	  it 'returns an array of payment options  with count 4', vcr: { cassette_name: 'get_available_offer_data_session_id_valid' } do
        expect(tt_booking_offer_data.payment_options).to be_a(Array)
        expect(tt_booking_offer_data.payment_options.count).to be(4)
  	  end

      it 'all elements are of type TtApi::PaymentOption', vcr: { cassette_name: 'get_available_offer_data_session_id_valid' } do
        contains_only_payment_optins = tt_booking_offer_data.payment_options.all? do |payment_option|
          payment_option.is_a?(TtApi::PaymentOption)
        end
        expect(contains_only_payment_optins).to be(true)
      end
  	end
  end

  context 'when expired session id' do
  	describe '#get_available_offer_data' do
  	  it 'returns nil', vcr: { cassette_name: 'get_available_offer_data_session_id_expired' } do
  	    expect(tt_booking_offer_data).to be(nil)
  	  end
  	end
  end

  context 'when valid payment token and valid offer id and valid session_id' do
    describe '#send_to_tt' do
      it 'returns a TtApi::Booking object with status.success true', vcr: { cassette_name: 'send_booking_to_tt_valid_payment_token_valid_offer_id' } do
        expect(tt_booking_shopping_card_data.status[:success]).to be(true)
      end
    end

    describe '#finalize_shopping_cart' do
      it 'returns true', vcr: { cassette_name: 'finalize_shopping_cart_valid_payment_token_valid_offer_id' } do
        expect(tt_booking_shopping_card_data.finalize_shopping_cart).to be(true)
      end
    end
  end

  context 'when invalid payment token and invalid offer id and invalid session_id' do
    describe '#send_to_tt' do
      it 'returns a TtApi::Booking object with status.success false', vcr: { cassette_name: 'send_booking_to_tt_invalid_payment_token_invalid_offer_id' } do
        expect(tt_booking_shopping_card_data.status[:success]).to be(false)
      end
    end

    describe '#finalize_shopping_cart' do
      it 'returns false', vcr: { cassette_name: 'finalize_shopping_cart_invalid_payment_token_invalid_offer_id' } do
        expect(tt_booking_shopping_card_data.finalize_shopping_cart).to be(false)
      end
    end
  end

  context 'when valid payment token and valid offer id and valid session_id but touroperator system returns timeout' do
    describe '#send_to_tt' do
      it 'returns a TtApi::Booking object with status.success true without transaction_id', vcr: { cassette_name: 'send_booking_to_tt_valid_payment_token_valid_offer_id_touroperator_timeout' } do
        expect(tt_booking_shopping_card_data.status[:success]).to be(true)
      end
    end
  end


end
