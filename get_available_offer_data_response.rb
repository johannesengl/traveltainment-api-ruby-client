module TtApi
  class GetAvailableOfferDataResponse

    STATUS_SUCCESS_NO = 1000

    def initialize(raw_response)
      @raw_response = raw_response
    end

    def success?
      status && status[:status_no].to_i == STATUS_SUCCESS_NO
    end

    def room
      return nil unless success?
      offer_data[:package][:accommodation][:room][:name] if offer_data[:package].present? && offer_data[:package][:accommodation][:room][:name].present?
    end

    def cautions
      return nil unless success?
      if offer_data[:cautions].is_a?(Hash) && offer_data[:cautions][:caution].is_a?(Array)
        offer_data[:cautions][:caution].select{|e| e.is_a? String}.join("<br>")
      else
        return nil
      end
    end

    def booking_types
      return nil unless success?
      booking_types = offer_data[:available_booking_types] if offer_data[:available_booking_types].present?
      [booking_types] if booking_types.is_a?(String)
    end

    def payment_data
      return nil unless success?
      if offer_data[:available_payments][:payment].present?
        payments = [offer_data[:available_payments][:payment]] if offer_data[:available_payments][:payment].is_a?(Hash)
        payments = offer_data[:available_payments][:payment] if offer_data[:available_payments][:payment].is_a?(Array)
      end
    end

    def status
      return false unless offer_data
      offer_data[:status]
    end

    protected

    def response_content
      @raw_response.body[:booking_package_get_available_offer_data_response][:return] if @raw_response.body[:booking_package_get_available_offer_data_response].present?
    end

    def offer_data
      response_content[:offer] if response_content && response_content[:offer].present?
    end

  end
end
