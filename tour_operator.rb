module TtApi
  class TourOperator
    def self.fetch_terms_and_conditions(tour_operator_code, departure_date)
      response = Client.get_terms_and_conditions(tour_operator_code, departure_date)
      return nil unless self.fetch_terms_and_conditions_success?(response)
      response.body[:booking_get_terms_and_conditions_response][:return][:terms_and_conditions]
    end

    protected

    def self.fetch_terms_and_conditions_success?(response)
      response.body[:booking_get_terms_and_conditions_response].present? &&
      response.body[:booking_get_terms_and_conditions_response][:return].present? &&
      response.body[:booking_get_terms_and_conditions_response][:return][:terms_and_conditions].present? &&
      response.body[:booking_get_terms_and_conditions_response][:return][:terms_and_conditions] != "No Terms and Conditions available."
    end
  end
end
