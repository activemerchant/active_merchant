module Braintree
  class VenmoAccount
    include BaseModule # :nodoc:

    attr_reader :created_at
    attr_reader :customer_id
    attr_reader :default
    attr_reader :image_url
    attr_reader :source_description
    attr_reader :subscriptions
    attr_reader :token
    attr_reader :updated_at
    attr_reader :username
    attr_reader :venmo_user_id

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
