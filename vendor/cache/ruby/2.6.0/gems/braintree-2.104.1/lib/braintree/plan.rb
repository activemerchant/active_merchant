module Braintree
  class Plan
    include BaseModule

    attr_reader :add_ons
    attr_reader :billing_day_of_month
    attr_reader :billing_frequency
    attr_reader :created_at
    attr_reader :currency_iso_code
    attr_reader :description
    attr_reader :discounts
    attr_reader :id
    attr_reader :merchant_id
    attr_reader :name
    attr_reader :number_of_billing_cycles
    attr_reader :price
    attr_reader :trial_duration
    attr_reader :trial_duration_unit
    attr_reader :trial_period
    attr_reader :updated_at

    def self.all
      Configuration.gateway.plan.all
    end

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      add_ons.map! { |attrs| AddOn._new(attrs) }
      discounts.map! { |attrs| Discount._new(attrs) }
      @price = Util.to_big_decimal(price)
    end

    class << self
      protected :new
    end

    def self._new(*args)
      self.new *args
    end
  end
end
