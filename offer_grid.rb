module TtApi
  class OfferGrid

    attr_accessor :data

    def initialize(departure_airport_iata_code, hotel_iff_code, nights_min, nights_max)
      @data = {}
      @departure_airport_iata_code, @hotel_iff_code, @nights_min, @nights_max = departure_airport_iata_code, hotel_iff_code, nights_min, nights_max
    end

    def fetch_offers(departure_date, return_date)
      offer_grid_response = TtApi::Client.search_engine_offer_grid(@departure_airport_iata_code, @hotel_iff_code, @nights_min, @nights_max, departure_date, return_date)
      @data = offer_grid_response.offer_grid || {}
      OFFER_LOGGER.info("Empty response for Departure Airport: #{@departure_airport_iata_code}, Hotel: #{@hotel_iff_code}, NightsMin: #{@nights_min}, NightsMax: #{@nights_max}, DepartureDate: #{departure_date}, ReturnDate: #{return_date}") if @data.present?
      @data
    end

    def include_offers(persisted_offers)
      persisted_offers.reverse.each do |persisted_offer|
        include_offer(persisted_offer)
      end
    end

    def teaser_offer(date, nights)
      return @data[:teaser_offer] if @data[:teaser_offer]
      all_offers = @data.values.flatten.compact.sort_by(&:price)
      all_offer_items = all_offers.select{|o| o.is_a?(OfferItem)}
      filtered_offers = all_offers
      filtered_offers = filtered_offers.select {|o| o.is_a?(Offer) ? (o.outbound_flight.departure_date.to_date.to_s == date) : (o.departure_date.to_s == date)} if date && date >= Date.current
      filtered_offers = filtered_offers.select {|o| o.nights == nights.to_i} if nights

      if date && date >= Date.current
        teaser_offer = fetch_teaser_offer(date, nights)
      end

      if !teaser_offer
        teaser_offer = all_offers.select{|o| o.is_a?(Offer)}.first
      end

      if !teaser_offer
        teaser_offer = find_available_and_direct_flight_offer_item(all_offer_items) if all_offer_items.any?
      end

      include_offer(teaser_offer) if teaser_offer
      @data[:teaser_offer] = teaser_offer if teaser_offer
    end

    protected

    def include_offer(persisted_offer)
      @data[persisted_offer.outbound_flight.departure_date.try(:to_date)] ||= []
      offer_date_array = @data[persisted_offer.outbound_flight.departure_date.try(:to_date)]

      index_to_replace = index_of_same_offer(offer_date_array, persisted_offer)
      no_match_found = index_to_replace.nil?

      if no_match_found
        offer_date_array.unshift(persisted_offer)
      else
        offer_date_array[index_to_replace] = persisted_offer
      end
    end

    def index_of_same_offer(offer_date_array, persisted_offer)
      offer_date_array.find_index do |offer_grid_item|
        offer_grid_item.nights == persisted_offer.nights
      end
    end

    def fetch_teaser_offer(date, nights)
      max_nights = (nights || 4).to_i
      offer_list_response = TtApi::Client.search_engine_offer_list(@departure_airport_iata_code, @hotel_iff_code, nights, nil, date, date + max_nights.days)

      offer_items = offer_list_response.cheapest_offer_items(20).map do |offer_item|
        TtApi::OfferItem.create_from_offer_list_data(offer_item, @hotel_iff_code, @departure_airport_iata_code)
      end

      offer_items = offer_items.select{|o| o.departure_date == date }.sort_by(&:price)
      find_available_and_direct_flight_offer_item(offer_items) || false
    end

    def find_available_and_direct_flight_offer_item(offer_items)
      index_of_available = offer_items.find_index do |offer_item|
        offer_item.fetch_price_and_availability
        offer_item.available && offer_item.direct_flight
      end

      if index_of_available
        offer_item = offer_items[index_of_available]
        return create_offer(offer_item) || false
      end
    end

    def create_offer(offer_item)
      offer_factory = TtApi::OfferFactory.new
      Offer.where(tt_id: offer_item.tt_id, available: true).update_all(available: false)
      offer = offer_factory.create_offer(offer_item)
      Offer.including_discount.find(offer.id)
    end

  end
end
