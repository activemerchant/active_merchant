module Braintree
  class UsBankAccount
    include BaseModule

    attr_reader :account_holder_name
    attr_reader :account_type
    attr_reader :ach_mandate
    attr_reader :bank_name
    attr_reader :default
    attr_reader :image_url
    attr_reader :last_4
    attr_reader :routing_number
    attr_reader :token
    attr_reader :verifications
    attr_reader :verified

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
      @ach_mandate = AchMandate.new(attributes[:ach_mandate]) if attributes[:ach_mandate]

      if attributes[:verifications]
        @verifications = attributes[:verifications].map do |v|
          UsBankAccountVerification._new(v)
        end
      end
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

    def self.find(*args)
      Configuration.gateway.us_bank_account.find(*args)
    end

    def self.sale(token, transaction_attributes)
      Configuration.gateway.transaction.sale(transaction_attributes.merge(
          :payment_method_token => token,
          :options => { :submit_for_settlement => true }
        )
      )
    end

    def self.sale!(token, transaction_attributes)
      return_object_or_raise(:transaction) { sale(token, transaction_attributes) }
    end
  end
end
