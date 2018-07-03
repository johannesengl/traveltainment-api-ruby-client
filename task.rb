module TtApi
  class Task
    MAIN_AIRPORT_IATA_CODES = ['SXF', 'TXL']

    def fetch_best_offers(iata_codes=nil, iff_codes=nil, number_nights=nil, check_availability=true)
      start_time = Time.current

      TT_TASK_ANALYZER.reset
      TT_API_LOGGER.info("Started travel tainment task! Started at: #{start_time}")

      if iata_codes && check_availability
        TT_API_LOGGER.info("Fetching offers for #{iata_codes.join(', ')}")
        excluded_iata_codes = Airport.where(departure_airport: true).pluck(:iata_code) - iata_codes
        offers = Offer.live.with_departure_airport_iata_codes(excluded_iata_codes)
        TT_API_LOGGER.info("Started cloning #{offers.count} live offers")
        clone_offers(offers)
        TT_API_LOGGER.info("Cloned #{Offer.where(is_clone: true, created_at: start_time..Time.now).count} offers")
      end

      iata_codes = Airport.where(departure_airport: true).pluck(:iata_code) unless iata_codes.present?
      iff_codes = Hotel.pluck(:iff_code) unless iff_codes.present?
      number_nights = Night.pluck(:nights) unless number_nights.present?

      offer_factory = TtApi::OfferFactory.new

      TtApi::LockedTourOperators.reset

      iata_codes.each do |iata_code|
        iff_codes.each do |iff_code|
          number_nights.each do |number_nights|

            OFFER_LOGGER.info("CurrentSet:
              Hotel: #{iff_code}
              Airport: #{iata_code}
              Nights: #{number_nights}")

            should_not_be_fetched = MAIN_AIRPORT_IATA_CODES.exclude?(iata_code) && Hotel.find_by(iff_code: iff_code).fetch_only_for_main_airports
            if should_not_be_fetched
              OFFER_LOGGER.info("Skip set, hotel set to fetch_only_for_main_airports")
              next
            end

            begin
              offer_set = TtApi::OfferSet.new(iata_code, iff_code, number_nights)
              offer_items = offer_set.fetch_offers(check_availability)

              offer_factory.process_offer_items(offer_items)
            rescue Exception => e
              OFFER_LOGGER.info("Exception while processing set. Message: #{e}")
            end
          end
        end
      end

      TT_API_LOGGER.info("Refreshing materialized view / Recalculating average prices")
      Offer.refresh_materialized_view

      finish_time = Time.current
      duration = (finish_time - start_time) / 60

      unless (task_info = TaskInfo.where(created_at: Time.now.beginning_of_day..Time.now.end_of_day).first)
        task_info = TaskInfo.create(
          started_at: start_time,
          performed_availability_checks: 0,
          created_non_alternative: 0,
          created_alternatives: 0,
          status: ""
        )
      end

      task_info.update(
        finished_at: finish_time,
        performed_availability_checks: task_info.performed_availability_checks + TT_TASK_ANALYZER.availability_checks,
        created_non_alternative: task_info.created_non_alternative + TT_TASK_ANALYZER.cheap_non_alternative_offers,
        created_alternatives: task_info.created_alternatives + TT_TASK_ANALYZER.alternative_offers,
        offers_created_during_task: Offer.where(created_at: task_info.started_at..finish_time).count,
        status: "#{task_info.status} #{TT_TASK_ANALYZER.print_status_info}"
      )

      send_mail_for_new_offers(task_info)

      task_info.log
    end

    def check_availability_of_live_offers
      start_time = Time.current

      TT_TASK_ANALYZER.reset
      TT_API_LOGGER.info("Started check availability for live offers! Started at: #{start_time}")
      teasered_offers = Offer.live.cheap.where(price: 0..600).to_a
      teasered_offers.each do |offer|
        OFFER_LOGGER.info("Try updating offer #{offer.outbound_flight.departure_airport.iata_code} -> #{offer.hotel.name} (#{offer.hotel.city.name}) #{offer.nights} Nights")

        begin
          if Offer.fetch_again_via_availability_check(offer)
            OFFER_LOGGER.info("Updated Offer successfully: #{offer.id}")
          else
            OFFER_LOGGER.info("Offer not available anymore: #{offer.id}")
          end
        rescue Exception => e
          OFFER_LOGGER.info("Exception trying to update offer #{offer.id}. Message: #{e}")
        end

      end

      TT_API_LOGGER.info("Refreshing materialized view / Recalculating average prices")
      Offer.refresh_materialized_view

      finish_time = Time.current
      duration = (finish_time - start_time) / 60

      task_info = TaskInfo.create(
        started_at: start_time,
        finished_at: finish_time,
        performed_availability_checks: TT_TASK_ANALYZER.availability_checks)

      task_info.log
    end

    protected

    def send_mail_for_new_offers(task_info)
      last_task_with_offers = TaskInfo.with_offers_created.order(created_at: :desc).where.not(id: task_info.id).first

      offers_old = Offer
        .select(:hotel_id, 'flights.departure_airport_id')
        .joins(:outbound_flight)
        .where(was_live: true, created_at: last_task_with_offers.started_at..task_info.started_at)
        .group(:hotel_id, 'flights.departure_airport_id')

      offers_today = Offer
        .select(:hotel_id, 'flights.departure_airport_id')
        .joins(:outbound_flight)
        .where(was_live: true, created_at: task_info.started_at..Time.current)
        .live
        .group(:hotel_id, 'flights.departure_airport_id')

      new_offer_sets = offers_today.map {|o| [o.hotel_id, o.departure_airport_id]} - offers_old.map {|o| [o.hotel_id, o.departure_airport_id]}
      new_offers = []

      new_offer_sets.each do |o|
        airport_code = Airport.find(o[1]).iata_code
        best_offers = Offer.alternatives_for_hotel_and_departure_airport(o[0], airport_code)
          .to_a.uniq {|o| o.nights}

        new_offers += best_offers
      end

      TaskMailer.conclusion_email(new_offers.sort_by{|offers| offers.price}, task_info).deliver
    end

    def clone_offers(offers)
      offers.each do |offer|
        offer_clone = offer.dup
        offer_clone.outbound_flight = offer.outbound_flight.dup if offer.outbound_flight
        offer_clone.inbound_flight = offer.inbound_flight.dup if offer.inbound_flight
        offer_clone.is_clone = true
        offer_clone.is_promoted = false
        offer_clone.created_at = Time.now
        offer_clone.tt_id = (0...30).map { (65 + rand(26)).chr }.join
        offer_clone.save
      end
    end

  end
end
