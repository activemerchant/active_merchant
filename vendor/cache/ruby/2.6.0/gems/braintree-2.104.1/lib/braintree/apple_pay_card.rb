module Braintree
  class ApplePayCard
    include BaseModule # :nodoc:

    module CardType
      AmEx = "Apple Pay - American Express"
      Visa = "Apple Pay - Visa"
      MasterCard = "Apple Pay - MasterCard"

      All = constants.map { |c| const_get(c) }
    end

    attr_reader :bin
    attr_reader :card_type
    attr_reader :created_at
    attr_reader :customer_id
    attr_reader :default
    attr_reader :expiration_month
    attr_reader :expiration_year
    attr_reader :expired
    attr_reader :image_url
    attr_reader :last_4
    attr_reader :payment_instrument_name
    attr_reader :source_description
    attr_reader :subscriptions
    attr_reader :token
    attr_reader :updated_at

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @subscriptions = (@subscriptions || []).map { |subscription_hash| Subscription._new(@gateway, subscription_hash) }
    end

    def default?
      @default
    end

    def expired?
      @expired
    end

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end
  end
end
