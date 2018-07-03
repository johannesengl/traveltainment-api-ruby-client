module TtApi
  class Booking
    attr_accessor :cautions, :payment_options, :booking_types, :status,
                  :request_ref, :tt_id, :shopping_cart_id, :transaction_id,
                  :request_id, :room, :reservation_id

    def self.get_available_offer_data(session_id)
      response = Client.get_available_offer_data(session_id)
      BOOKING_LOGGER.info("Booking Available Offer Data Request: Session ID: #{session_id}")
      BOOKING_LOGGER.info("Booking Available Offer Data Status: #{response.status.inspect}")
      BOOKING_LOGGER.info("Booking Available Payment Methods: #{response.payment_data.inspect}")
      return nil unless response.success?
      Booking.create_from_available_offer_response(response)
    end

    def self.create_from_available_offer_response(response)
      booking = Booking.new
      booking.cautions = response.cautions
      booking.room = response.room
      booking.payment_options = compose_payment_options(response.payment_data)
      booking.booking_types = response.booking_types
      booking
    end

    def self.send_to_tt(booking, payment_token)
      raise "No payment token for send booking to tt!" unless payment_token
      booking.validate_for_sending_to_tt
      booking.customer.validate_for_sending_to_tt
      response = Client.booking_book_shopping_cart(booking, payment_token)
      BOOKING_LOGGER.info("Book Shopping Cart Request: Booking: #{booking.inspect}, Payment Token: #{payment_token.inspect}")
      BOOKING_LOGGER.info("Book Shopping Cart Status: #{response.status.inspect}")
      BOOKING_LOGGER.info("Book Shopping Cart Data: request_ref: #{response.request_ref.inspect}, tt_id: #{response.tt_id.inspect}, shopping_cart_id: #{response.shopping_cart_id.inspect}, transaction_id: #{response.transaction_id.inspect}, request_id: #{response.request_id.inspect}")
      Booking.create_from_book_shopping_cart_response(response)
    end

    def self.create_from_book_shopping_cart_response(response)
      booking = Booking.new
      booking.status = response.status
      booking.request_ref = response.request_ref
      booking.tt_id = response.tt_id
      booking.shopping_cart_id = response.shopping_cart_id
      booking.transaction_id = response.transaction_id
      booking.request_id = response.request_id
      booking.reservation_id = response.reservation_id
      booking
    end

    def finalize_shopping_cart
      return false if self.shopping_cart_id.nil?
      BOOKING_LOGGER.info("Finalize Shopping Cart Request: Shopping Cart: #{self.shopping_cart_id}")
      response = Client.finalize_shopping_cart(self.shopping_cart_id)
      BOOKING_LOGGER.info("Finalize Shopping Cart Response: #{response.body[:booking_finalize_shopping_cart_response][:return]}")
      response.body[:booking_finalize_shopping_cart_response][:return][:@success] == "true"
    end

    def booked?
      status && self.status[:success]
    end

    def booking_status
      if self.booked?
        :booked
      else
        :error
      end
    end

    protected

    def self.compose_payment_options(payments)
      payments.map do |payment|
        next if not_supported_payment?(payment)
        PaymentOption.new(payment)
      end
    end

    def self.not_supported_payment?(payment)
      ['direct_debit', 'agency', 'ideal', 'phone',  'pay_pal', 'undefined', 'unique_accreditation'].include?(payment[:@payment_type].snakecase)
    end

  end
end
