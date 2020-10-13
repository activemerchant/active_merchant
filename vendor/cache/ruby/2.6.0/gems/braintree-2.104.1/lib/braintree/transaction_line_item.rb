module Braintree
  class TransactionLineItem
    include BaseModule
    attr_reader :quantity
    attr_reader :name
    attr_reader :description
    attr_reader :kind
    attr_reader :unit_amount
    attr_reader :unit_tax_amount
    attr_reader :unit_of_measure
    attr_reader :discount_amount
    attr_reader :tax_amount
    attr_reader :total_amount
    attr_reader :product_code
    attr_reader :commodity_code
    attr_reader :url

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @quantity = Util.to_big_decimal(quantity)
      @unit_amount = Util.to_big_decimal(unit_amount)
      @unit_tax_amount = Util.to_big_decimal(unit_tax_amount)
      @discount_amount = Util.to_big_decimal(discount_amount)
      @tax_amount = Util.to_big_decimal(tax_amount)
      @total_amount = Util.to_big_decimal(total_amount)
    end

    class << self
      protected :new
      def _new(*args) # :nodoc:
        self.new *args
      end
    end

    def self.find_all(*args)
      Configuration.gateway.transaction_line_item.find_all(*args)
    end
  end
end
