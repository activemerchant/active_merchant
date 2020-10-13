module Braintree
  class Gateway
    attr_reader :config, :graphql_client

    def initialize(config)
      if config.is_a?(Hash)
        @config = Configuration.new config
      elsif config.is_a?(Braintree::Configuration)
        @config = config
      else
        raise ArgumentError, "config is an invalid type"
      end

      @graphql_client = GraphQLClient.new(@config)
    end

    def add_on
      AddOnGateway.new(self)
    end

    def address
      AddressGateway.new(self)
    end

    def apple_pay
      ApplePayGateway.new(self)
    end

    def client_token
      ClientTokenGateway.new(self)
    end

    def credit_card
      CreditCardGateway.new(self)
    end

    def customer
      CustomerGateway.new(self)
    end

    def discount
      DiscountGateway.new(self)
    end

    def dispute
      DisputeGateway.new(self)
    end

    def document_upload
      DocumentUploadGateway.new(self)
    end

    def oauth
      OAuthGateway.new(self)
    end

    def plan
      PlanGateway.new(self)
    end

    def payment_method
      PaymentMethodGateway.new(self)
    end

    def payment_method_nonce
      PaymentMethodNonceGateway.new(self)
    end

    def paypal_account
      PayPalAccountGateway.new(self)
    end

    def us_bank_account
      UsBankAccountGateway.new(self)
    end

    # NEXT_MAJOR_VERSION Remove this class as legacy Ideal has been removed/disabled in the Braintree Gateway
    # DEPRECATED If you're looking to accept iDEAL as a payment method contact accounts@braintreepayments.com for a solution.
    def ideal_payment
      IdealPaymentGateway.new(self)
    end

    def merchant
      MerchantGateway.new(self)
    end

    def merchant_account
      MerchantAccountGateway.new(self)
    end

    def europe_bank_account
      EuropeBankAccountGateway.new(self)
    end

    def settlement_batch_summary
      SettlementBatchSummaryGateway.new(self)
    end

    def subscription
      SubscriptionGateway.new(self)
    end

    def transparent_redirect
      TransparentRedirectGateway.new(self)
    end

    def transaction
      TransactionGateway.new(self)
    end

    def transaction_line_item
      TransactionLineItemGateway.new(self)
    end

    def testing
      TestingGateway.new(self)
    end

    def us_bank_account_verification
      UsBankAccountVerificationGateway.new(self)
    end

    def verification
      CreditCardVerificationGateway.new(self)
    end

    def webhook_notification
      WebhookNotificationGateway.new(self)
    end

    def webhook_testing
      WebhookTestingGateway.new(self)
    end
  end
end
