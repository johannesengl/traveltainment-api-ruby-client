module TtApi
  class OfferItem
    include Draper::Decoratable
    attr_accessor :tt_id, :price, :nights, :tour_operator, :departure_date,
      :special_journey_attributes, :catering, :available, :hotel_iff_code,
      :departure_airport_iata_code, :direct_flight, :flights, :status,
      :tour_operator_notice, :session_id, :number_passengers

    PRICE_FOR_FLIGHT_BOUNDS = 100
    PRICE_PER_NIGHT_BOUNDS = 100
    PRICE_FOR_FLIGHT_LOW_ABS = 100
    PRICE_PER_NIGHT_LOW_ABS = 75
    MAX_PRICE = 2000

    def initialize
      @available = false
    end

    def self.create_from_offer_list_data(data, hotel_iff_code, departure_airport_iata_code, number_passengers=2)
      offer = OfferItem.new
      offer.tt_id = data[:offer_id]
      offer.price = data[:price_information][:original_price].to_f
      offer.nights = data[:travel_duration]
      offer.tour_operator = data[:tour_operator][:code]
      offer.departure_date = data[:departure_date]
      offer.special_journey_attributes = data[:special_journey_attributes]
      offer.catering = data[:package][:accommodation][:meal][:meal]
      offer.hotel_iff_code = hotel_iff_code
      offer.departure_airport_iata_code = departure_airport_iata_code
      offer.number_passengers = number_passengers

      offer
    end

    def self.create_from_offer_grid_data(data, departure_date, hotel_iff_code, number_passengers=2)
      offer = OfferItem.new
      offer.tt_id = data[:offer_id]
      offer.price = data[:price_information][:original_price].to_f
      offer.nights = data[:travel_duration].to_i
      offer.tour_operator = data[:tour_operator]
      offer.departure_date = departure_date.to_date
      offer.special_journey_attributes = data[:special_journey_attributes]
      offer.catering = data[:meal]
      offer.hotel_iff_code = hotel_iff_code
      offer.departure_airport_iata_code = data[:departure_airport].attributes["IataCode"]
      offer.number_passengers = number_passengers

      offer
    end

    def self.create_from_availability_check(response)
      offer = OfferItem.new
      offer.price = response.price
      offer.available = response.available?
      offer.direct_flight = response.direct_flight?
      offer.flights = response.flights
      offer.status = response.status
      offer.tour_operator_notice = response.tour_operator_notice
      offer.tt_id = response.tt_id
      offer.nights = response.nights
      offer.tour_operator = response.tour_operator
      offer.departure_date = response.departure_date
      offer.special_journey_attributes = ""
      offer.catering = response.catering
      offer.hotel_iff_code = response.hotel_iff_code
      offer.departure_airport_iata_code = response.departure_airport_iata_code
      offer.session_id = response.session_id
      offer.number_passengers = response.passengers.count

      offer
    end

    def decorate
      OfferItemDecorator.decorate(self)
    end

    def below_max_price?
      @price && @price <= MAX_PRICE
    end

    def cheap?
      offer_set = ::OfferSet.find_by(hotel: Hotel.find_by(iff_code: self.hotel_iff_code),
        departure_airport: Airport.find_by(iata_code: self.departure_airport_iata_code))

      required_discount = offer_set.try(:required_discount) || Offer::REQUIRED_DISCOUNT_FOR_CHEAP
      has_enough_discount = avg_discount >= required_discount
      cheap = has_enough_discount && has_price_within_bounds

      cheap || (should_check_abs_price && has_low_abs_price)
    end

    def has_price_within_bounds
      @price <= PRICE_FOR_FLIGHT_BOUNDS + PRICE_PER_NIGHT_BOUNDS * @nights.to_i
    end

    def has_low_abs_price
      @price <= PRICE_FOR_FLIGHT_LOW_ABS + PRICE_PER_NIGHT_LOW_ABS * @nights.to_i
    end

    def should_check_abs_price
      Hotel.find_by(iff_code: @hotel_iff_code).select_on_abs_price
    end

    def avg_discount
      return -1 unless @price && average > 0
      ((1 - @price / average) * 100)
    end

    def average
      @average ||= get_average_price_of_same_set
    end

    def discount
      return -1 unless @price && maximum > 0
      ((1 - @price / maximum) * 100)
    end

    def maximum
      @maximum ||= get_maximum_price_of_same_set
    end

    def highlight?
      discount >= Offer::DISCOUNT_FOR_HIGHLIGHT
    end

    def fetch_price_and_availability
      return false unless is_eligible_for_availability?

      TT_TASK_ANALYZER.availability_checks +=1
      response = TtApi::Client.availability_and_price_check(@tt_id, @number_passengers)

      update_from_price_and_availability_check(response)
    end

    protected

    def is_eligible_for_availability?
      has_published_hotel? # && !has_locked_tour_operator?
    end

    def has_locked_tour_operator?
      if TtApi::LockedTourOperators.include?(@tour_operator)
        OFFER_LOGGER.info "Availability check aborted. Tour operator #{@tour_operator} is locked"
        OFFER_LOGGER.info "Locked Tour Operators: #{TtApi::LockedTourOperators.list.inspect}"
        return true
      end
    end

    def has_published_hotel?
      Hotel.find_by(iff_code: self.hotel_iff_code).try(:published)
    end

    def get_average_price_of_same_set
      sql = "SELECT * FROM offer_sets_mv INNER JOIN airports ON airports.id = offer_sets_mv.departure_airport_id INNER JOIN hotels ON hotels.id = offer_sets_mv.hotel_id WHERE airports.iata_code = '#{@departure_airport_iata_code}' AND hotels.iff_code = #{@hotel_iff_code} AND nights = #{@nights} AND catering = '#{@catering}';"
      results = ActiveRecord::Base.connection.execute(sql)
      return 0 if results.to_a.empty?
      results.first["price_avg"].to_f
    end

    def get_maximum_price_of_same_set
      sql = "SELECT * FROM offer_sets_mv INNER JOIN airports ON airports.id = offer_sets_mv.departure_airport_id INNER JOIN hotels ON hotels.id = offer_sets_mv.hotel_id WHERE airports.iata_code = '#{@departure_airport_iata_code}' AND hotels.iff_code = #{@hotel_iff_code} AND nights = #{@nights} AND catering = '#{@catering}';"
      results = ActiveRecord::Base.connection.execute(sql)
      return 0 if results.to_a.empty?
      results.first["price_max"].to_f
    end

    def update_from_price_and_availability_check(response)
      TtApi::LockedTourOperators.add(@tour_operator) if response.is_locked_operator?

      @available = response.available?
      @price = response.price || @price
      @direct_flight = response.direct_flight?
      @flights = response.flights
      @status = response.status
      @tour_operator_notice = response.tour_operator_notice
      @session_id = response.session_id

      self
    end

  end
end
