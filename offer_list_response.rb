module TtApi
  class OfferListResponse

    def initialize(raw_response)
      @raw_response = raw_response
      @offers = extract_offers_from_response
    end

    def cheapest_offer_items(number_offers=Offer::SIZE_LIMIT_OFFER_LIST_RESPONSE)
      @cheapest_offer_items ||= select_cheapest_offer_items(number_offers)
    end

    protected

    def extract_offers_from_response
      result_sets = @raw_response.body[:search_package_offer_list_response][:return][:result_set]
      list_items = []
      list_items << result_sets[:list_item] if (result_sets.is_a?(Hash) && result_sets[:list_item].present?)
      list_items << result_sets.map([], :list_item).flatten if result_sets.is_a?(Array)
      list_items.flatten.map {|list_item| list_item[:offer] }
    end

    def select_cheapest_offer_items(number_offers)
      offers_for_selection = @offers
      offers_for_selection.sort_by! { |offer| offer[:price_information][:original_price].to_i }
      offers_for_selection = reject_alternatives(offers_for_selection)

      breakfast_offer = extract_first_breakfast_offer(offers_for_selection)
      offers_for_selection.unshift(breakfast_offer) unless breakfast_offer.nil?
      offers_for_selection[0...number_offers]
    end

    def reject_alternatives(offers)
      offers.reject { |offer| is_alternative(offer) }
    end

    def is_alternative(offer)
      offer[:weightage].to_i < 100 || offer[:alternative]
    end

    def extract_first_breakfast_offer(offers)
      breakfast_offer = offers.find do |offer|
        offer[:package][:accommodation][:meal][:meal] == "BREAKFAST"
      end
      offers.delete(breakfast_offer)
    end

  end
end
