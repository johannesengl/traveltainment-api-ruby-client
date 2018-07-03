module TtApi
  class OfferFactory

    def process_offer_items(offer_items)
      log_offer_items(offer_items)
      if offer_items.any? && offer_items.first.below_max_price?
        create_cheapest_offer(offer_items)
        create_all_available_offers(offer_items)
      end
    end

    def create_offer(offer_item)
      if offer_item.available and offer_item.direct_flight
        create_offer_with_all_data(offer_item)
      else
        create_offer_for_average_prices(offer_item)
      end
    end

    protected

    def log_offer_items(offer_items)
      offer_items.each do |offer_item|
        OFFER_LOGGER.info("Offer Status: #{offer_item.status} (#{offer_item.tour_operator})") if offer_item.status.present?
        TT_TASK_ANALYZER.analyze_status(offer_item.status, offer_item.tour_operator) if offer_item.status.present?
        TT_TASK_ANALYZER.alternative_offers +=1 if offer_item.available && !offer_item.cheap?

        if offer_item.available && offer_item.direct_flight
          TT_TASK_ANALYZER.cheap_non_alternative_offers += 1
          OFFER_LOGGER.info("Found cheap available package! #{offer_item.tt_id}")
        else
          if offer_item.cheap?
            OFFER_LOGGER.info("Offer cheap but not applicable for Frontend!
              OfferID: #{offer_item.tt_id}
              Nights: #{offer_item.nights}
              IffCode: #{offer_item.hotel_iff_code}
              IataCode: #{offer_item.departure_airport_iata_code}
              Available?: #{offer_item.available}
              DirectFlight?: #{offer_item.direct_flight}
              Operator: #{offer_item.tour_operator}"
            )
          else
            OFFER_LOGGER.info("Offer not cheap #{offer_item.tt_id}")
          end
        end
      end

      OFFER_LOGGER.info("No cheap and available offers for Set.") if offer_items.select(&:available).empty?
    end

    def create_cheapest_offer(offer_items)
      create_offer(offer_items.sort_by(&:price).first)
    end

    def create_all_available_offers(offer_items)
      offer_items.select(&:available).each do |offer_item|
        begin
          create_offer(offer_item)
        rescue Exception => e
          OFFER_LOGGER.info("Exception while creating #{offer_item}. Message: #{e}")
        end
      end
    end

    def create_offer_with_all_data(offer_item)
      offer = create_offer_for_average_prices(offer_item)
      update_offer_with_flights_data(offer, offer_item.flights)
      offer
    end

    def update_offer_with_flights_data(offer, flights_data)
      destination_airport = find_or_create_destination_airport(flights_data[:outbound_flight][:destination_airport])
      offer.update(
        inbound_flight: Flight.create
      )

      update_flight(offer.outbound_flight, nil, destination_airport, flights_data[:outbound_flight])
      update_flight(offer.inbound_flight, destination_airport, offer.outbound_flight.departure_airport, flights_data[:inbound_flight])
    end

    def update_flight(flight, departure_airport, destination_airport, flight_data)
      flight = update_flight_with_flight_data(flight, flight_data)
      flight.departure_airport ||= departure_airport
      flight.destination_airport ||= destination_airport
      flight.save
    end

    def create_offer_for_average_prices(offer_item)
      hotel = Hotel.find_by(iff_code: offer_item.hotel_iff_code)
      departure_airport = Airport.find_by_iata_code(offer_item.departure_airport_iata_code)
      outbound_flight = Flight.create(departure_airport: departure_airport)
      tour_operator = ::TourOperator.find_or_create_by(code: offer_item.tour_operator) do |tour_operator|
        tour_operator.name = offer_item.tour_operator
      end

      special_journey_attributes = parse_special_journey_attributes(offer_item.special_journey_attributes)

      offer = Offer.create(
        available: offer_item.available,
        direct_flight: offer_item.direct_flight,
        price: offer_item.price,
        hotel: hotel,
        nights: offer_item.nights,
        catering: offer_item.catering,
        outbound_flight: outbound_flight,
        tour_operator: tour_operator,
        tt_id: offer_item.tt_id,
        tour_operator_notice: offer_item.tour_operator_notice,
        transfer: special_journey_attributes[:transfer],
        railfly: special_journey_attributes[:railandfly],
        number_passengers: offer_item.number_passengers
      )
    end

    def update_flight_with_flight_data(flight, flight_data)
      airline = Airline.find_or_create_by(carrier_code: flight_data[:airline][:carrier_code]) do |airline|
        airline.name = flight_data[:airline][:name]
      end

      flight.update(
        airline: airline,
        flight_number: flight_data[:flight_number],
        departure_date: flight_data[:departure_date],
        arrival_date: flight_data[:arrival_date],
        assured: flight_data[:assured]
      )
      flight
    end

    def find_or_create_destination_airport(destination_airport_name)
      if destination_airport_name.is_a?(Nori::StringWithAttributes) && destination_airport_name.attributes["IataCode"].present?
        Airport.find_or_create_by(iata_code: destination_airport_name.attributes["IataCode"]) do |airport|
          airport.name = destination_airport_name
        end
      else
        Airport.find_or_create_by(name: destination_airport_name)
      end
    end

    def parse_special_journey_attributes(special_journey_attributes_data)
      {
        transfer: special_journey_attributes_data.try(:include?, 'TRANSFER') || false,
        railandfly: special_journey_attributes_data.try(:include?, 'RAILANDFLY') || false
      }
    end

  end
end
