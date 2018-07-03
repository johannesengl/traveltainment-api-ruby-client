NOT_LOCKED_STATUS_TEXTS = [
  "flight booked out",
  "room booked out",
  "offer available",
  "offer booked out",
  "offer to confirm available",
  "could not request the flight",
  "offer on request available",
  "flight not found",
  "room not found",
  "could not request hotel",
  "duration not available in this hotel"
]

ALLOWED_BOOKING_TYPES = [
  "BookOnFix"
]

module TtApi
  class AvailabilityAndPriceCheckResponse

    def initialize(raw_response)
      @raw_response = raw_response
      OFFER_LOGGER.info "#{response_content[:status]}"
    end

    def status
      status = {
        no: response_content[:status][:status_no],
        no_text: response_content[:status][:status_no_text],
        text: response_content[:status][:status_text],
        status: response_content[:status][:status]
      }
    end

    def flights
      return nil unless direct_flight? && available?

      flights = {
        outbound_flight: compose_flight(flights_data[:outbound_flight_segments]),
        inbound_flight: compose_flight(flights_data[:inbound_flight_segments])
      }
    end

    def price
      determine_price
    end

    def is_locked_operator?
      !NOT_LOCKED_STATUS_TEXTS.include?(status[:no_text])
    end

    def available?
      OFFER_LOGGER.info("Offer not available because only possible BookingTypes are: #{booking_types.join(', ')}") if status_available? && !includes_allowed_booking_types? && booking_types.is_a?(Array)
      status_available? && includes_allowed_booking_types?
    end

    def direct_flight?
      return false unless available?
      flights_data[:outbound_flight_segments][:flight_segment].is_a?(Hash) &&
      flights_data[:inbound_flight_segments][:flight_segment].is_a?(Hash) &&
      flights_data[:outbound_flight_segments][:flight_segment][:flight_date_time_span].present? &&
      flights_data[:inbound_flight_segments][:flight_segment][:flight_date_time_span].present?
    end

    def flight_assured?
      return false unless available?
      flights_data[:outbound_flight_segments][:flight_segment][:@assured] == "true" &&
      flights_data[:inbound_flight_segments][:flight_segment][:@assured] == "true"
    end

    def tour_operator_notice
      return false unless available?
      response_content[:offer].present? &&
      response_content[:offer][:cautions].present? &&
      response_content[:offer][:cautions].is_a?(Hash) &&
      response_content[:offer][:cautions][:caution].is_a?(Array) &&
        response_content[:offer][:cautions][:caution].select{|e| e.is_a? String}.join("<br>")
    end

    def tt_id
      return false unless available?
      response_content[:offer][:offer_id]
    end

    def nights
      return false unless available?
      start_date = departure_date
      end_date = Date.parse(response_content[:offer][:offer_date_span][:@end])
      (end_date - start_date).to_i
    end

    def tour_operator
      return false unless available?
      response_content[:offer][:tour_operator][:code]
    end

    def departure_date
      return false unless available?
      Date.parse(response_content[:offer][:offer_date_span][:@start])
    end

    def catering
      return false unless available?
      response_content[:offer][:package][:accommodation][:meal]
    end

    def hotel_iff_code
      return false unless available?
      response_content[:offer][:package][:accommodation][:object_id].to_i
    end

    def departure_airport_iata_code
      return false unless available?
      response_content[:offer][:package][:flight][:outbound_flight_segments][:departure_airport].attributes["IataCode"]
    end

    def session_id
      return false unless available?
      response_content[:@session_id]
    end

    def passengers
      passenger_data = response_content.try(:[], :traveller_list).try(:[], :traveller)
      passenger_data.is_a?(Array) ? passenger_data : [passenger_data]
    end

    protected

    def response_content
      @raw_response.body[:booking_package_availability_and_price_check_response][:return]
    end

    def flights_data
      response_content[:offer][:package][:flight]
    end

    def booking_types
      return [] unless status_available?
      [response_content[:available_booking_types][:booking_type]].flatten
    end

    def compose_flight(flight_segment)
      flight = {
        departure_airport: flight_segment[:departure_airport],
        destination_airport: flight_segment[:destination_airport],
        airline: {
          carrier_code: flight_segment[:flight_segment][:carrier_code],
          name: flight_segment[:flight_segment][:airline]
        },
        flight_number: flight_segment[:flight_segment][:flight_number].to_s,
        departure_date: Time.zone.parse(flight_segment[:flight_segment][:flight_date_time_span][:@start]),
        arrival_date: Time.zone.parse(flight_segment[:flight_segment][:flight_date_time_span][:@end]),
        assured: (flight_segment[:flight_segment][:@assured] == "true")
      }
    end

    def determine_price
      price_data = response_content[:price_information]
      if price_data.present?
        calculate_price(price_data)
      else
        return nil
      end
    end

    def calculate_price(price_data)
      if price_data[:traveller_price_list].present? && price_data[:traveller_price_list][:traveller_price].any?
        price_from_first_traveller(price_data[:traveller_price_list])
      else
        calculate_price_from_total(price_data)
      end
    end

    def price_from_first_traveller(traveller_price_list)
      if traveller_price_list[:traveller_price].is_a?(Array)
        traveller_price_list[:traveller_price].first[:amount].to_f
      else
        traveller_price_list[:traveller_price][:amount].to_f
      end
    end

    def calculate_price_from_total(price_data)
      price_data[:total_price][:amount].to_f / passengers.count
    end

    def status_available?
      status[:no] == Offer::OFFER_AVAILABLE_STATUS
    end

    def includes_allowed_booking_types?
      ALLOWED_BOOKING_TYPES.any? {|booking_type| booking_types.include?(booking_type) }
    end

  end
end
