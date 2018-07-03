module TtApi
  class OfferGridResponse

    attr_accessor :offer_grid

    def initialize(raw_response)
      @response = raw_response.body[:search_package_offer_grid_response][:return]
      if success?
        @hotel_iff_code = @response[:hotel][:object_id].to_i
        @offer_grid = compose_offer_grid
      end
    end

    protected

    def success?
      @response[:offer_grid].present?
    end

    def compose_offer_grid
      grid = {}
      days = @response[:offer_grid][:group][:element]
      days.each do |day|
        offer_items = []
        offer_items = create_offer_items(day[:group][:element], day[:@value]) if day_has_offers?(day)
        grid[day[:@value].to_date] = offer_items
      end
      grid
    end

    def create_offer_items(offers, departure_date)
      offers = [offers] if offers.is_a?(Hash)
      offers = offers.map do |offer_data|
        OfferItem.create_from_offer_grid_data(offer_data[:offer], departure_date, @hotel_iff_code) if offer_data[:offer].present?
      end
      offers.compact
    end

    def day_has_offers?(day)
      day[:group].present? && day[:group][:element].present?
    end

  end
end
