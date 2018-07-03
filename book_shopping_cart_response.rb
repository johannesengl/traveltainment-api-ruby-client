STATUS_TYPE_SUCCESS = ["Booked", "Undefined"]
STATUS_TYPE_SUCCESS_STAGING = ["NotBooked", "Booked", "Undefined"]

module TtApi
  class BookShoppingCartResponse
    def initialize(raw_response)
      @raw_response = raw_response
    end

    def success?
      response_content.present? &&
      booking_data.present? &&
      success_status_types.include?(booking_data[:status][:status_type])
    end

    def error
      if response_content[:errors].present?
        response_content[:errors][:error][:error_msg] if response_content[:errors].is_a?(Hash)
      end
    end

    def status
      if success?
        status = {
          success: true,
          type: booking_data[:status][:status_type],
          no: booking_data[:status][:status_no].to_i,
          no_text: booking_data[:status][:status_no_text],
          text: booking_data[:status][:status_text],
          status: booking_data[:status][:status]
        }
      else
        status = {
          success: false,
          errors: composed_errors
        }
      end
    end

    def request_ref
      return nil unless success?
      booking_data[:@book_request_ref]
    end

    def tt_id
      return nil unless success?
      booking_data[:booking_id]
    end

    def shopping_cart_id
      return nil unless success?
      response_content[:shopping_cart_id]
    end

    def transaction_id
      return nil unless success?
      response_content[:rs_metadata][:@transaction_id]
    end

    def reservation_id
      return nil unless success?
      booking_data[:reservation_id]
    end

    def request_id
      response_content[:rs_metadata][:@request_id]
    end

    protected

    def response_content
      @raw_response.body[:booking_book_shopping_cart_response][:return] if @raw_response.body[:booking_book_shopping_cart_response].present?
    end

    def booking_data
      response_content[:booking_results][:booking_result] if response_content[:booking_results].present?
    end

    def composed_errors
      return [response_content[:errors]] if response_content[:errors].is_a?(Hash)
      return response_content[:errors] if response_content[:errors].is_a?(Array)
      return [{error: {error_code: 'error_not_booked'}}]
    end

    def success_status_types
      (ENV['ENVIRONMENT'] == 'production') ? STATUS_TYPE_SUCCESS : STATUS_TYPE_SUCCESS_STAGING
    end
  end
end
