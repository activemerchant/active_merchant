require 'nokogiri'
require 'active_merchant/billing/gateways/maxipago/maxipago_common_api'
require 'active_merchant/billing/gateways/maxipago/maxipago_recurring_api'
require 'active_merchant/billing/gateways/maxipago/maxipago_boleto_api'
require 'active_merchant/billing/gateways/maxipago/maxipago_bank_transfer_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MaxipagoGateway < Gateway
      include MaxipagoCommonAPI
      include MaxipagoRecurringAPI
      include MaxipagoBoletoAPI
      include MaxipagoBankTransferAPI

      # TODO: Tests, Docs and OnlineDebit

      def purchase(money, creditcard_or_payment_type, options = {})
        if creditcard_or_payment_type == :boleto_bancario
          options[:processor_id] = options[:extras][:boleto_processor_id]
          generate_boleto(money, options)
        elsif creditcard_or_payment_type == :bank_transfer
          options[:processor_id] = options[:extras][:debit_processor_id]
          bank_transfer(money, options)
        else
          options[:processor_id] = options[:extras][:credit_processor_id]
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
        post = if options[:type] == :transaction
         { transaction_id: identifier }
        else
         { order_id: identifier }
        end

        commit(build_detail_request(post), :report)
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
