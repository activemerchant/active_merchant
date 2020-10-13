module Braintree
  module TransparentRedirect
    module Kind # :nodoc:
      CreateCustomer = "create_customer"
      UpdateCustomer = "update_customer"
      CreatePaymentMethod = "create_payment_method"
      UpdatePaymentMethod = "update_payment_method"
      CreateTransaction = "create_transaction"
    end

    def self.confirm(*args)
      Configuration.gateway.transparent_redirect.confirm(*args)
    end

    def self.create_credit_card_data(*args)
      Configuration.gateway.transparent_redirect.create_credit_card_data(*args)
    end

    def self.create_customer_data(*args)
      Configuration.gateway.transparent_redirect.create_customer_data(*args)
    end

    def self.transaction_data(*args)
      Configuration.gateway.transparent_redirect.transaction_data(*args)
    end

    def self.update_credit_card_data(*args)
      Configuration.gateway.transparent_redirect.update_credit_card_data(*args)
    end

    def self.update_customer_data(*args)
      Configuration.gateway.transparent_redirect.update_customer_data(*args)
    end

    # Returns the URL to which Transparent Redirect Requests should be posted
    def self.url
      Configuration.gateway.transparent_redirect.url
    end
  end
end
