require 'active_merchant/billing/gateways/sage/sage_core'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageBankcardGateway < Gateway #:nodoc:
      include SageCore
      self.live_url = 'https://www.sagepayments.net/cgi-bin/eftBankcard.dll?transaction'
      self.source = 'bankcard'

      # Credit cards supported by Sage
      # * VISA
      # * MasterCard
      # * AMEX
      # * Diners
      # * Carte Blanche
      # * Discover
      # * JCB
      # * Sears
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      def authorize(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_transaction_data(post, money, options)
        commit(:authorization, post)
      end

      def purchase(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_transaction_data(post, money, options)
        commit(:purchase, post)
      end

      # The +money+ amount is not used. The entire amount of the
      # initial authorization will be captured.
      def capture(money, reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:capture, post)
      end

      def void(reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:void, post)
      end

      def credit(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_transaction_data(post, money, options)
        commit(:credit, post)
      end

      def refund(money, reference, options={})
        post = {}
        add_reference(post, reference)
        add_transaction_data(post, money, options)
        commit(:refund, post)
      end

      private

      def add_credit_card(post, credit_card)
        post[:C_name]       = credit_card.name
        post[:C_cardnumber] = credit_card.number
        post[:C_exp]        = expdate(credit_card)
        post[:C_cvv]        = credit_card.verification_value if credit_card.verification_value?
      end

      def parse(data)
        response = {}
        response[:success]          = data[1,1]
        response[:code]             = data[2,6]
        response[:message]          = data[8,32].strip
        response[:front_end]        = data[40, 2]
        response[:cvv_result]       = data[42, 1]
        response[:avs_result]       = data[43, 1].strip
        response[:risk]             = data[44, 2]
        response[:reference]        = data[46, 10]

        response[:order_number], response[:recurring] = data[57...-1].split("\034")
        response
      end
    end
  end
end

