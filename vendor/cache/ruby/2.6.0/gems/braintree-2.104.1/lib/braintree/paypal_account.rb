module Braintree
  class PayPalAccount
    include BaseModule

    attr_reader :billing_agreement_id
    attr_reader :created_at
    attr_reader :customer_id
    attr_reader :email
    attr_reader :image_url
    attr_reader :payer_id
    attr_reader :revoked_at
    attr_reader :subscriptions
    attr_reader :token
    attr_reader :updated_at

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @subscriptions = (@subscriptions || []).map { |subscription_hash| Subscription._new(@gateway, subscription_hash) }
    end

    class << self
      protected :new
    end

    def self._new(*args)
      self.new(*args)
    end

    def self.create(attributes)
      Configuration.gateway.paypal_account.create(attributes)
    end

    def self.find(token)
      Configuration.gateway.paypal_account.find(token)
    end

    def self.update(token, attributes)
      Configuration.gateway.paypal_account.update(token, attributes)
    end

    def self.delete(token)
      Configuration.gateway.paypal_account.delete(token)
    end

    def self.sale(token, transaction_attributes)
      Configuration.gateway.transaction.sale(transaction_attributes.merge(:payment_method_token => token))
    end

    def self.sale!(token, transaction_attributes)
      return_object_or_raise(:transaction) { sale(token, transaction_attributes) }
    end

    # Returns true if this paypal account is the customer's default payment method.
    def default?
      @default
    end
  end
end
