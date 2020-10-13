module Braintree
  class CoinbaseAccount
    include BaseModule # :nodoc:

    attr_reader :created_at
    attr_reader :customer_id
    attr_reader :default
    attr_reader :subscriptions
    attr_reader :token
    attr_reader :updated_at
    attr_reader :user_email
    attr_reader :user_id
    attr_reader :user_name

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @subscriptions = (@subscriptions || []).map { |subscription_hash| Subscription._new(@gateway, subscription_hash) }
    end

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end

    # Returns true if this coinbase account is the customer's default payment method.
    def default?
      @default
    end
  end
end
