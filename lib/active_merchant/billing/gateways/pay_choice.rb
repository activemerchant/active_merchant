begin
  require "pay_choice"
rescue LoadError
  raise "Could not load the PayChoice gem.  Use `gem install pay_choice` to install it."
end

module ActiveMerchant
  module Billing
    class PayChoiceGateway < Gateway
      self.money_format = :dollars
      self.default_currency = 'AUD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = "http://www.paychoice.com.au/"
      self.display_name = "PayChoice"
      self.supported_countries = ['AU']

      class PayChoiceGatewayPurchase < Hash
        attr_accessor :gateway

        def self.create gateway, response
          result = self[response]
          result.gateway = gateway
          result
        end
        def success?
          charge = self["charge"]
          charge.try(:[],"status") == "Approved" && charge.try(:[],"error_code") == "0"
        end
        def authorization
          self["charge"].try(:[],"id")
        end
        def test?
          self.gateway.test?
        end
      end

      def initialize(options)
        requires!(options, :login, :password)
        @login = options[:login]
        @password = options[:password]
        super
      end

      def purchase(money, card, options = {})
        result = init.create(
          currency: options[:currency] || currency(money),
          amount: money,
          reference: "Invoice #{Time.now.to_i}",
          card: to_hash_from_credit_card(card)
        )
        PayChoiceGatewayPurchase.create self, result
      end

      def list
        init.list
      end

      def get id
        result = init.get id
      end

      def get_card id
        result = init.get_card id
      end

      # TODO: Example on http://www.paychoice.com.au/docs/api/v3/ is currently broken
      #
      def authorize(money, card, options = {})
        # Ignore params for basic_auth
        result = init.basic_auth
      end

      def store(card)
        result = init.store_card(to_hash_from_credit_card(card))
      end

     private

      def init
        environment = test? ? :sandbox : :production

        PayChoice.new({
          username: @login,
          password: @password}, environment)
      end

      def to_hash_from_credit_card(credit_card)
        {
          name: credit_card.first_name + credit_card.last_name,
          number: credit_card.number,
          expiry_month: credit_card.month,
          expiry_year: credit_card.year,
          cvv: credit_card.verification_value
        }
      end
    end
  end
end
