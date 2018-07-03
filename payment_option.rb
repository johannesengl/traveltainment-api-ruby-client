module TtApi
  class PaymentOption

    attr_accessor :type, :surcharge, :label,
                  :description, :card_code, :bank_account

    @data

    def initialize(payment_data)
      @data = payment_data
      set_attributes
    end

    def set_attributes
      @type = @data[:@payment_type].snakecase
      @label = I18n.t("booking.payment.types.#{@data[:@payment_type].snakecase}")
      @description = I18n.t("booking.payment.descriptions.#{@data[:@payment_type].snakecase}")
      add_surcharge
      set_credit_card_code
      set_bank_account_type if is_bank_account?
    end

    def is_credit_card?
      @type == 'credit_card'
    end

    def is_bank_account?
      ['bank_acct_int', 'bank_acct', 'direct_debit_international'].include? @type
    end

    protected

    def contains_surcharge?
      @data[:surcharge].present?
    end

    def add_surcharge
      if contains_surcharge?
        @surcharge = @data[:surcharge].merge(@data[:surcharge]) { |k, v| Float(v) rescue v }
      end
    end

    def set_credit_card_code
      @card_code = @data[:credit_card_info][:@credit_card_type] if is_credit_card?
    end

    def set_bank_account_type
      @type = 'bank_account'
    end

  end
end
