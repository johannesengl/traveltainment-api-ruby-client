module TtApi
  class TTTaskAnalyzer

	RESERVATIONS_SYSTEM_ERROR_STATUS = "5023"

	attr_accessor :availability_checks, :cheap_non_alternative_offers, :alternative_offers, :locked_tour_operators, :offer_status, :offer_status_description

	def initialize
		reset
	end

	def reset
		@availability_checks = 0
		@cheap_non_alternative_offers = 0
		@alternative_offers = 0
		@locked_tour_operators = Set.new []
		@offer_status = {}
		@offer_status_description = {}
	end

	def print_status_info
		status_desc_with_no_offers = offer_status.keys.map { |e| [offer_status_description[e], offer_status[e]].join(": ")  }
		status_desc_with_no_offers.join(", ")
	end

	def analyze_status(status, tour_operator)
		analyze_locked_tour_operator(tour_operator) if status[:no] == RESERVATIONS_SYSTEM_ERROR_STATUS

		if offer_status[status[:no]].present?
			offer_status[status[:no]] += 1
		else
			offer_status[status[:no]] = 1
		end

		offer_status_description[status[:no]] = status[:no_text]
	end

	private

	def analyze_locked_tour_operator(tour_operator)
		locked_tour_operators << tour_operator
	end

  end
end
