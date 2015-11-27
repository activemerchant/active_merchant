require 'nokogiri'
require 'active_merchant/billing/gateways/maxipago/maxipago_common_api'
require 'active_merchant/billing/gateways/maxipago/maxipago_recurring_api'
require 'active_merchant/billing/gateways/maxipago/maxipago_boleto_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MaxipagoGateway < Gateway
      include MaxipagoCommonAPI
      include MaxipagoRecurringAPI
      include MaxipagoBoletoAPI

      # TODO: Tests, Docs and OnlineDebit

      def purchase(money, creditcard_or_payment_type, options = {})
        if creditcard_or_payment_type == 'Boleto'
          generate_boleto(money, options)
        else
          common_purchase(money, creditcard_or_payment_type, options)
        end
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_aux_data(post, options)
        add_amount(post, money)
        add_creditcard(post, creditcard)
        add_name(post, creditcard)
        add_address(post, options)

        commit(build_sale_request(post, "auth"))
      end

      def capture(money, authorization, options = {})
        post = {}
        add_amount(post, money)
        add_aux_data(post, options)
        commit(build_capture_request(authorization, post))
      end

      def details(identifier, options = {})
        post = if options[:type] == :order
         { order_id: identifier }
        else
         { transaction_id: identifier }
        end

        commit(build_detail_request(post))
      end

      private

      def build_capture_request(authorization, params)
        build_transaction_request(params) do |xml|
          xml.capture! {
            xml.orderID authorization
            xml.referenceNum params[:referenceNum]
            xml.payment {
              xml.chargeTotal params[:amount]
            }
          }
        end
      end
    end
  end
end
