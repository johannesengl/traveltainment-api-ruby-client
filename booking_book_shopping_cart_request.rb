module TtApi
  class BookingBookShoppingCartRequest


  	def initialize(booking, payment_token)
  		@booking = booking
  		@payment_token = payment_token
  	end

  	def to_s
  		request = ''
  		xm = Builder::XmlMarkup.new(:target=>request)
  		xm.soapenv :Envelope, {'xmlns:soapenv'=>'http://schemas.xmlsoap.org/soap/envelope/',
  			'xmlns:web'=>'http://webservice.middleware.traveltainment.de/'} do
  			xm.soapenv :Header
  			xm.soapenv :Body do
  				xm.web :Booking_BookShoppingCart do
  					xm.request('Version'=>'1.6') do
  						xm.RQ_Metadata('IsTest'=>ENV['TT_REQUEST_IS_TEST'], 'Language'=>'de-DE')
  						xm.SessionID(@booking.session_id)
  						travelers_xml(xm, @booking.passengers)
  						customer_xml(xm, @booking.customer)
  						xm.BookRequests do
  							xm.BookTravelRequest('BookRequestID' => "BR-#{@booking.id}") do
  								xm.OfferID(@booking.offer.tt_id)
  								xm.BookingType(ENV['TT_BOOKING_TYPE'])
  								xm.PaymentTokens do
  									xm.PaymentToken(@payment_token, 'ID' => 'P1', 'PaymentType' => payment_type)
  								end
  							end
  						end
  					end
  				end
  			end
  		end
  		request
  	end

  	def travelers_xml(xm, passengers)
  		xm.Travellers do
  			passengers.each do |passenger|
  				passenger = passenger.decorate
  				xm.Traveller('ID' => passenger.id) do
  					xm.PersonName do
  						xm.FirstName(passenger.firstname)
  						xm.LastName(passenger.lastname)
              xm.Salutation(passenger.salutation)
  					end
  					xm.Gender(passenger.gender_full)
  					xm.BirthDate(passenger.birthdate)
  					xm.AgeQualifier(passenger.age_qualifier)
  				end
  			end
  		end
  	end

  	def customer_xml(xm, customer)
  		decorated_customer = customer.decorate
  		xm.Customer do
  			xm.PersonName do
  				xm.FirstName(decorated_customer.firstname)
  				xm.LastName(decorated_customer.lastname)
          xm.Salutation(decorated_customer.salutation)
  			end
  			xm.Gender(decorated_customer.gender_full)
        xm.BirthDate(decorated_customer.birthdate)
  			xm.Contacts do
  				xm.Contact(decorated_customer.email, 'LocationType' => 'Home', 'TechType' => 'Email')
  				xm.Contact(decorated_customer.phone_number, 'LocationType' => 'Home', 'TechType' => 'Mobile')
  			end
  			xm.Addresses do
  				xm.Address('Status' => 'Original', 'LocationType' => 'Home') do
  					xm.StreetNumber("#{decorated_customer.street} #{decorated_customer.streetnumber}")
  					xm.CityName(decorated_customer.city, 'PostalCode' => decorated_customer.zip)
  					xm.CountryName(decorated_customer.country, 'Code' => 'DE')
  				end
  			end
  		end
  	end

    protected

    def payment_type
      if @booking.payment_type == "bank_account"
        "DirectDebitInternational"
      else
        @booking.payment_type.camelcase
      end
    end
  end
end
