module Braintree
  # NEXT_MAJOR_VERSION Remove this class.
  # DEPRECATED The American Express Checkout payment method is deprecated.
  class AmexExpressCheckoutCard
    include BaseModule # :nodoc:

    attr_reader :bin
    attr_reader :card_member_expiry_date
    attr_reader :card_member_number
    attr_reader :card_type
    attr_reader :created_at
    attr_reader :customer_id
    attr_reader :default
    attr_reader :expiration_month
    attr_reader :expiration_year
    attr_reader :image_url
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

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end
  end
end
