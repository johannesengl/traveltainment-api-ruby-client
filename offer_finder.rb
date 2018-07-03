module TtApi
  class OfferFinder

    def self.fetch_offer_item_with_id(id, number_passengers=2)
      availability_check_response = TtApi::Client.availability_and_price_check(id, number_passengers)
      TT_TASK_ANALYZER.availability_checks +=1
      offer_item = TtApi::OfferItem.create_from_availability_check(availability_check_response)
      return offer_item.available && offer_item
    end

    def self.fetch_matching_offer(departure_airport_iata_code, hotel_iff_code, nights,
        catering, departure_date, return_date, outbound_flight_number,
        inbound_flight_number, number_passengers)
      offer_list_response = TtApi::Client.search_engine_offer_list(
        departure_airport_iata_code, hotel_iff_code, nights, catering,
        departure_date, return_date, nil, nil, nil, number_passengers)

      offer_item = find_matching_offer(offer_list_response.cheapest_offer_items,
        hotel_iff_code, departure_airport_iata_code, outbound_flight_number,
        inbound_flight_number, number_passengers)

      offer_item || false
    end

    protected

    def self.find_matching_offer(offer_items, hotel_iff_code, departure_airport_iata_code, outbound_flight_number,
        inbound_flight_number, number_passengers)
      available_direct_flight_offers = offer_items.each_with_index.map do |offer_item, index|
        break if index == 4 && available_direct_flight_offers.try(:any?) && available_direct_flight_offers.compact.first

        offer = TtApi::OfferItem.create_from_offer_list_data(offer_item, hotel_iff_code, departure_airport_iata_code, number_passengers)
        offer.fetch_price_and_availability
        if offer.available && offer.direct_flight
          # Offer might not have flight data due to non direct flight. In this case no matching offer is found.
          matching_outbound_flight = offer.flights.present? && offer.flights[:outbound_flight][:flight_number] == outbound_flight_number
          matching_inbound_flight = offer.flights.present? && offer.flights[:inbound_flight][:flight_number] == inbound_flight_number
          return offer if matching_outbound_flight && matching_inbound_flight
          offer
        end
      end
      return available_direct_flight_offers.compact.first || false
    end

  end
end
