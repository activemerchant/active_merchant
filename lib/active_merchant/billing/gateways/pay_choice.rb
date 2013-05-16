require 'activemerchant'

module ActiveMerchant
  module Billing
    class PayChoiceGateway < Gateway
      self.money_format = :dollars
      self.default_currency = 'AUD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = "http://www.paychoice.com.au/"
      self.display_name = "PayChoice"

      def initialize(options)
        requires!(options, :login, :password)
        @login = options[:login]
        @password = options[:password]
        super
      end

      def purchase(money, card, options = {})
        init.create(
          currency: options[:currency] || currency(money),
          amount: money,
          reference: "Invoice #{Time.now.to_i}",
          card: to_hash_from_credit_card(card)
        )
      end

      def list
        init.list
      end

      def get id
        init.get id
      end

      def get_card id
        init.get_card id
      end

      # TODO: Example on http://www.paychoice.com.au/docs/api/v3/ is currently broken
      #
      def authorize(money, card, options = {})
        # Ignore params for basic_auth
        init.basic_auth
      end

      def store(card)
        init.store_card(to_hash_from_credit_card(card))
      end

     private

      def init
        PayChoice.new(
          username: @login,
          password: @password
        )
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
