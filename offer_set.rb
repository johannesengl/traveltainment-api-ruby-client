module TtApi
  class OfferSet

    REQUIRED_NUMBER_OF_AVAILABLE_OFFERS = 5
    MAX_NUMBER_OF_AVAILABLE_OFFERS = 6

    def initialize(departure_airport_iata_code, hotel_iff_code, nights)
      @departure_airport_iata_code, @hotel_iff_code, @nights = departure_airport_iata_code, hotel_iff_code, nights
      load_offer_set_discount
    end

    def fetch_offers(check_availability)
      return @cheapest_offers if @cheapest_offers

      offer_list_response = TtApi::Client.search_engine_offer_list(@departure_airport_iata_code, @hotel_iff_code, @nights)
      cheapest_offer_items = offer_list_response.cheapest_offer_items
      OFFER_LOGGER.info("Empty response for Departure Airport: #{@departure_airport_iata_code}, Hotel: #{@hotel_iff_code}, Nights: #{@nights}") if cheapest_offer_items.empty?
      offers = create_offers_from_items(cheapest_offer_items)
      find_first_cheap_and_available_offer(offers) if check_availability
      @cheapest_offers = offers
    end

    protected

    def create_offers_from_items(offer_items)
      offer_items.map do |offer_item|
        TtApi::OfferItem.create_from_offer_list_data(offer_item, @hotel_iff_code, @departure_airport_iata_code)
      end
    end

    def load_offer_set_discount
      @offer_set = ::OfferSet.where(departure_airport_id: Airport.find_by(iata_code: @departure_airport_iata_code), hotel_id: Hotel.find_by(iff_code: @hotel_iff_code)).first_or_initialize
      airport = Airport.find_by(iata_code: @departure_airport_iata_code)
      city = airport.city
      airports = city.try(:airports) || [airport]
      @number_available_offers_for_airport = Offer.live.cheap.where(airports: {id: airports}).live.to_a.uniq {|offer| offer.hotel_id}.count
    end

    def find_first_cheap_and_available_offer(offers)
      set_discount_for_set(offers.first.avg_discount) if offers.any?

      offers.find_index do |offer|
        if offer.cheap?
          offer.fetch_price_and_availability
          unless offer.cheap?
            offer.available = false
            OFFER_LOGGER.info "Offer #{offer.tt_id} not cheap anymore after availability check"
          end
        end

        offer.available
      end
    end

    def set_discount_for_set(unchecked_discount)
      discount_in_eligible_range = (0 < unchecked_discount && unchecked_discount < Offer::REQUIRED_DISCOUNT_FOR_CHEAP)
      needs_more_available_offers = (@number_available_offers_for_airport < REQUIRED_NUMBER_OF_AVAILABLE_OFFERS)
      has_too_many_available_offers = (@number_available_offers_for_airport > MAX_NUMBER_OF_AVAILABLE_OFFERS)
      has_not_been_set_manually = (@offer_set.new_record? || @offer_set.required_discount == 0)

      if discount_in_eligible_range && has_not_been_set_manually
        OFFER_LOGGER.info "Setting discount for #{@departure_airport_iata_code}, #{@hotel_iff_code}, #{@nights} to 0 (had #{@number_available_offers_for_airport} offers)" if needs_more_available_offers
        @offer_set.update(required_discount: 0) if needs_more_available_offers
        OFFER_LOGGER.info "Removing discount for #{@departure_airport_iata_code}, #{@hotel_iff_code}, #{@nights} (had #{@number_available_offers_for_airport} offers)" if has_too_many_available_offers
        @offer_set.destroy if has_too_many_available_offers
      end
    end

    def fetch_price_and_availability_for_alternatives(offers, start_index)
      offers[start_index..-1].each do |offer|
        if offer.discount >= Offer::REQUIRED_DISCOUNT_FOR_ALTERNATIVE
          offer.fetch_price_and_availability
        end
      end
    end

  end
end
