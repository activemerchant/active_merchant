module Braintree
  class Merchant
    include BaseModule # :nodoc:

    attr_reader :company_name
    attr_reader :country_code_alpha2
    attr_reader :country_code_alpha3
    attr_reader :country_code_numeric
    attr_reader :country_name
    attr_reader :email
    attr_reader :id
    attr_reader :merchant_accounts

    def initialize(gateway, attributes) # :nodoc:
      @merchant_accounts = attributes.delete(:merchant_accounts).map do |merchant_account|
        MerchantAccount._new(gateway, merchant_account)
      end

      set_instance_variables_from_hash(attributes)
    end

    class << self
      protected :new
    end

    def self._new(*args) # :nodoc:
      self.new *args
    end

    def self.provision_raw_apple_pay
      Configuration.gateway.merchant.provision_raw_apple_pay
    end
  end
end
