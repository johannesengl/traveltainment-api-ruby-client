module TtApi
  class Client
    WSDL_URL = "http://de-ttxml.traveltainment.eu/TTXml-1.6/DispatcherWS?wsdl"
    PROXY_URL = "http://52.28.47.86:80"

    def self.client
      @@client ||= Savon.client(
        wsdl: WSDL_URL,
        proxy: PROXY_URL,
        digest_auth: [ENV['TT_API_USER'], ENV['TT_API_PASSWORD']],
        convert_request_keys_to: :camelcase
      )
    end

    def self.search_engine_offer_list(departure_airport_iata_code, hotel_iff_code, number_nights, catering=nil, departure_date=Date.current, return_date=(Date.current + 84.days), number_results=100, result_offset=0, tour_operator_code=nil, number_passengers=2)
      request_xml_offer_list = ""

      min_nights = number_nights || 2
      max_nights = number_nights || 4

      xm = Builder::XmlMarkup.new(target: request_xml_offer_list)
      xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
        xm.soapenv :Header
        xm.soapenv :Body do
          xm.web :Search_Package_OfferList do
            xm.request('Target'=>ENV['TT_REQUEST_TARGET'], 'LanguageCode'=>'de-DE') do
              xm.Search do
                xm.Trip do
                  xm.Journey do
                    xm.DepartureAirportCountry('DE')
                    xm.TravellerList do
                      number_passengers.times do
                        xm.Traveller('Age' => '25')
                      end
                    end
                    xm.DepartureAirportList('Weightage'=> '100') do
                      xm.Airport(departure_airport_iata_code)
                    end
                    xm.TravelDateSpan do
                      xm.DepartureDate(departure_date.to_s, 'Weightage' => '100')
                      xm.ReturnDate(return_date.to_s, 'Weightage' => '100')
                    end
                    xm.TravelDurationSpan('Weightage' => '100') do
                      xm.MinDays(min_nights.to_s)
                      xm.MaxDays(max_nights.to_s)
                    end
                  end
                  if catering
                    xm.Hotel do
                      xm.MealType(catering, 'Weightage'=> '100')
                    end
                  end
                  if tour_operator_code
                    xm.TourOperator do
                      xm.Limit do
                        xm.TourOperator(tour_operator_code)
                      end
                    end
                  end
                end
                xm.Options do
                  xm.ResultsPerPage(number_results)
                  xm.ResultOffset(result_offset)
                  xm.Sorting('PERCENTAGEFIT')
                end
              end
              xm.Selection do
                xm.ObjectID(hotel_iff_code.to_s)
              end
            end
          end
        end
      end

      response = client.call(:search_package_offer_list, xml: request_xml_offer_list)
      TT_ALL_REQUESTS_LOGGER.info(request_xml_offer_list)
      TT_ALL_REQUESTS_LOGGER.info(response.http.code)
      TT_ALL_REQUESTS_LOGGER.info(response.http.headers)
      TT_ALL_REQUESTS_LOGGER.info(response.http.body)
      TtApi::OfferListResponse.new(response)
    end

    def self.search_engine_offer_grid(
      departure_airport_iata_code,
      hotel_iff_code,
      number_nights_min,
      number_nights_max,
      departure_date,
      return_date,
      catering=nil)
      request_xml_offer_grid = ""

      xm = Builder::XmlMarkup.new(target: request_xml_offer_grid)
      xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
        xm.soapenv :Header
        xm.soapenv :Body do
          xm.web :Search_Package_OfferGrid do
            xm.request('Target'=>ENV['TT_REQUEST_TARGET'], 'LanguageCode'=>'de-DE') do
              xm.Search do
                xm.Trip do
                  xm.Journey do
                    xm.DepartureAirportCountry('DE')
                    xm.TravellerList do
                      xm.Traveller('Age' => '25')
                      xm.Traveller('Age' => '25')
                    end
                    xm.DepartureAirportList('Weightage'=> '100') do
                      xm.Airport(departure_airport_iata_code)
                    end
                    xm.TravelDateSpan do
                      xm.DepartureDate(departure_date.to_s, 'Weightage' => '100')
                      xm.ReturnDate(return_date.to_s, 'Weightage' => '100')
                    end
                    xm.TravelDurationSpan('Weightage' => '100') do
                      xm.MinDays(number_nights_min.to_s)
                      xm.MaxDays(number_nights_max.to_s)
                    end
                    xm.PriceSpan('Weightage' => '100') do
                      xm.MaxPrice('2000')
                      xm.CurrencyCode('EUR')
                    end
                  end
                  if catering
                    xm.Hotel do
                      xm.MealType(catering, 'Weightage'=> '100')
                    end
                  end
                end
              end
              xm.Selection do
                xm.ObjectID(hotel_iff_code.to_s)
              end
              xm.GridGroupList("DEPARTUREDAY TRAVELDURATION")
            end
          end
        end
      end

      response = client.call(:search_package_offer_grid, xml: request_xml_offer_grid)
      TT_ALL_REQUESTS_LOGGER.info(request_xml_offer_grid)
      TT_ALL_REQUESTS_LOGGER.info(response.http.code)
      TT_ALL_REQUESTS_LOGGER.info(response.http.headers)
      TT_ALL_REQUESTS_LOGGER.info(response.http.body)
      TtApi::OfferGridResponse.new(response)
    end

    def self.availability_and_price_check(tt_id, number_passengers=2)
      firstnames = ['Hans', 'Maximilian', 'Till', 'Christian', 'Johannes', 'Peter']
      lastnames = ['Muller', 'Maier', 'Rogger', 'Saettele', 'Hag', 'Rehen']
      request_xml_availability_and_price_check = ""

      xm = Builder::XmlMarkup.new(target: request_xml_availability_and_price_check)
      xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
        xm.soapenv :Header
        xm.soapenv :Body do
          xm.web :Booking_Package_AvailabilityAndPriceCheck do
            xm.request('Target'=>ENV['TT_REQUEST_TARGET'], 'LanguageCode'=>'de-DE') do
              xm.OfferID(tt_id)
              xm.TravellerList do
                number_passengers.times do |i|
                  xm.Traveller do
                    xm.PersonName do
                      xm.FirstName(firstnames[i])
                      xm.LastName(lastnames[i])
                    end
                    xm.Gender('MALE')
                    xm.BirthDate('1967-08-13')
                    xm.Type('ADULT')
                  end
                end
              end
            end
          end
        end
      end

      response = client.call(:booking_package_availability_and_price_check, xml: request_xml_availability_and_price_check)
      TT_ALL_REQUESTS_LOGGER.info(request_xml_availability_and_price_check)
      TT_ALL_REQUESTS_LOGGER.info(response.http.code)
      TT_ALL_REQUESTS_LOGGER.info(response.http.headers)
      TT_ALL_REQUESTS_LOGGER.info(response.http.body)
      TtApi::AvailabilityAndPriceCheckResponse.new(response)
    end

    def self.get_available_offer_data(session_id)
      request_xml_get_available_offer_data = ""

      xm = Builder::XmlMarkup.new(target: request_xml_get_available_offer_data)
      xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
        xm.soapenv :Header
        xm.soapenv :Body do
          xm.web :Booking_Package_GetAvailableOfferData do
            xm.request('Version' => '1.6') do
              xm.RQ_Metadata('IsTest'=>ENV['TT_REQUEST_IS_TEST'], 'Language' => 'de-DE')
              xm.SessionID(session_id)
            end
          end
        end
      end

      response = client.call(:booking_package_get_available_offer_data, xml: request_xml_get_available_offer_data)
      TT_ALL_REQUESTS_LOGGER.info(request_xml_get_available_offer_data)
      TT_ALL_REQUESTS_LOGGER.info(response.http.code)
      TT_ALL_REQUESTS_LOGGER.info(response.http.headers)
      TT_ALL_REQUESTS_LOGGER.info(response.http.body)
      TtApi::GetAvailableOfferDataResponse.new(response)
    end

    def self.booking_book_shopping_cart(booking, payment_token)
      response = client.call(:booking_book_shopping_cart, xml: TtApi::BookingBookShoppingCartRequest.new(booking, payment_token).to_s)
      BOOKING_LOGGER.info("Book Shopping Cart Response: #{response.body}")
      TtApi::BookShoppingCartResponse.new(response)
    end

  	def self.get_terms_and_conditions(tour_operator_code, departure_date)
  		request_xml_get_terms_and_conditions = ""

  		xm = Builder::XmlMarkup.new(target: request_xml_get_terms_and_conditions)
  		xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
  		  'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
  		  xm.soapenv :Header
  		  xm.soapenv :Body do
  		    xm.web :Booking_GetTermsAndConditions do
  		      xm.request('Target' => ENV['TT_REQUEST_TARGET'], 'LanguageCode' => 'de-DE') do
  		      	xm.TourOperator(tour_operator_code)
  		      	xm.TravelBeginDate(departure_date)
  		      end
  		    end
  		  end
  		end

  		response = client.call(:booking_get_terms_and_conditions, xml: request_xml_get_terms_and_conditions)
      TT_ALL_REQUESTS_LOGGER.info(request_xml_get_terms_and_conditions)
      TT_ALL_REQUESTS_LOGGER.info(response.http.code)
      TT_ALL_REQUESTS_LOGGER.info(response.http.headers)
      TT_ALL_REQUESTS_LOGGER.info(response.http.body)
      response
  	end

    def self.finalize_shopping_cart(shopping_cart_id)
      request_xml_finalize_shopping_cart = ""

      xm = Builder::XmlMarkup.new(target: request_xml_finalize_shopping_cart)
      xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
        xm.soapenv :Header
        xm.soapenv :Body do
          xm.web :Booking_FinalizeShoppingCart do
            xm.request('Target' => ENV['TT_REQUEST_TARGET'], 'LanguageCode' => 'de-DE') do
              xm.ShoppingCartID(shopping_cart_id)
            end
          end
        end
      end
      response = client.call(:booking_finalize_shopping_cart, xml: request_xml_finalize_shopping_cart)
      TT_ALL_REQUESTS_LOGGER.info(request_xml_finalize_shopping_cart)
      TT_ALL_REQUESTS_LOGGER.info(response.http.code)
      TT_ALL_REQUESTS_LOGGER.info(response.http.headers)
      TT_ALL_REQUESTS_LOGGER.info(response.http.body)
      response
    end

    def self.get_alternative_flights_list(session_id)
      request_xml_get_alternative_flights_list = ""

      xm = Builder::XmlMarkup.new(target: request_xml_get_alternative_flights_list)
      xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
        xm.soapenv :Header
        xm.soapenv :Body do
          xm.web :Booking_Package_GetAlternativeFlightsList do
            xm.request('Target' => ENV['TT_REQUEST_TARGET'], 'LanguageCode' => 'de-DE') do
              xm.CID(session_id)
            end
          end
        end
      end
      response = client.call(:booking_package_get_alternative_flights_list, xml: request_xml_get_alternative_flights_list)
      TT_ALL_REQUESTS_LOGGER.info(request_xml_get_alternative_flights_list)
      TT_ALL_REQUESTS_LOGGER.info(response.http.code)
      TT_ALL_REQUESTS_LOGGER.info(response.http.headers)
      TT_ALL_REQUESTS_LOGGER.info(response.http.body)
      response
    end

  end
end
