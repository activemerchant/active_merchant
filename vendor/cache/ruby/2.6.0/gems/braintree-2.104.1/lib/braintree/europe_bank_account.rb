module Braintree
  class EuropeBankAccount
    include BaseModule

    module MandateType
      Business = 'business'
      Consumer = 'consumer'
    end

    attr_reader :customer_id
    attr_reader :image_url
    attr_reader :token

    def initialize(gateway, attributes) # :nodoc:
      @gateway = gateway
      set_instance_variables_from_hash(attributes)
    end

    class << self
      protected :new
    end

    def self._new(*args)
      self.new(*args)
    end

    def self.find(token)
      Configuration.gateway.europe_bank_account.find(token)
    end

    def default?
      @default
    end

  end
end
