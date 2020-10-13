module Braintree
  class Modification # :nodoc:
    include BaseModule

    attr_reader :amount
    attr_reader :created_at
    attr_reader :current_billing_cycle
    attr_reader :description
    attr_reader :id
    attr_reader :kind
    attr_reader :merchant_id
    attr_reader :name
    attr_reader :never_expires
    attr_reader :number_of_billing_cycles
    attr_reader :quantity
    attr_reader :updated_at

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end

    def initialize(attributes) # :nodoc:
      set_instance_variables_from_hash(attributes)
      @amount = Util.to_big_decimal(amount)
    end

    def never_expires?
      @never_expires
    end
  end
end
