# DEFAULT_LOCKED_TOUR_OPERATORS = ['NER', 'X5VF', 'XAIR', 'XALL', 'XBIG', 'XDEM',
#   'XDER', 'XETI', 'XFTI', 'XBU', 'HLX1', 'XJAH', 'JT', 'XLMX', 'XMWR', 'XNER',
#   'XNEC', 'SLRD', 'XTOC', 'XPOD', 'XTUI', 'VTO', 'WTA', 'XLTR', 'XALD', 'XOGE']

DEFAULT_LOCKED_TOUR_OPERATORS = ['NER']

module TtApi
  class LockedTourOperators

    def self.list
      @@list ||= reset
    end

    def self.add(operator)
      TT_API_LOGGER.info "Adding #{operator} to locked tour operators"
      TT_API_LOGGER.info "Locked Tour Operators: #{TtApi::LockedTourOperators.list.inspect}"
      list << operator
    end

    def self.include?(operator)
      list.include?(operator)
    end

    def self.reset
      @@list = Set.new
      DEFAULT_LOCKED_TOUR_OPERATORS.each {|operator| self.add(operator) }
      @@list
    end

  end
end
