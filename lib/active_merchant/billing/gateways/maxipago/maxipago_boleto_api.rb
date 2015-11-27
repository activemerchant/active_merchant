require 'active_merchant/billing/gateways/maxipago/maxipago_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in MaxipagoGateway
    module MaxipagoBoletoAPI
      # Create a recurring payment.
      #
      # This transaction creates a recurring payment profile
      # ==== Parameters
      #
      # * <tt>amount</tt> -- The amount to be charged to the customer at each interval as an Integer value in cents.
      # * <tt>credit_card</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:period</tt> -- [Day, Week, SemiMonth, Month, Year] default: Month
      # * <tt>:frequency</tt> -- a number
      # * <tt>:cycles</tt> -- Limit to certain # of cycles (OPTIONAL)
      # * <tt>:start_date</tt> -- When does the charging starts (REQUIRED)
      # * <tt>:description</tt> -- The description to appear in the profile (REQUIRED)
      def generate_boleto(amount, options = {})
        options[:amount] = amount
        requires!(options, :expiration_date, :number, :amount)

        post = {}
        add_aux_data(post, options)
        add_amount(post, money)
        add_creditcard(post, creditcard)
        add_name(post, creditcard)
        add_address(post, options)
        add_boleto(post, options)

        commit(build_sale_request(post))
      end

      def status_boleto(transaction_id, options = {})
        commit(build_detail_request({ transaction_id: transaction_id }))
      end

      private

      def add_boleto(post, options)
        post[:payment_type] = :boleto
        post[:expiration_date] = options[:expiration_date].strftime('%Y-%m-%d')
        post[:number] = options[:number]
        post[:instructions] = options[:instructions] if options[:instructions]
      end

    end
  end
end
