require 'active_merchant/billing/gateways/maxipago/maxipago_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in MaxipagoGateway
    module MaxipagoRecurringAPI
      # Create a recurring payment.
      #
      # This transaction creates a recurring payment transaction
      # ==== Parameters
      #
      # * <tt>amount</tt> -- The amount to be charged to the customer at each interval as an Integer value in cents.
      # * <tt>credit_card</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:period</tt> -- [monthly, weekly, daily] (REQUIRED)
      # * <tt>:frequency</tt> -- a number (REQUIRED)
      # * <tt>:installments</tt> -- Limit to certain # of cycles (REQUIRED)
      # * <tt>:start_date</tt> -- When does the charging starts (REQUIRED)
      def recurring(amount, credit_card, options = {})
        options[:credit_card] = credit_card
        options[:amount] = amount
        requires!(options, :start_date, :period, :frequency, :amount, :installments)

        post = {}
        add_aux_data(post, options)
        add_amount(post, amount)
        add_creditcard(post, credit_card)
        add_name(post, credit_card)
        add_address(post, options)
        add_recurring(post, options)

        commit(build_sale_request(post, "recurringPayment"))
      end

      def cancel_recurring(order_id, options = {})
        commit(build_api_request('cancel-recurring', order_id), :api)
      end

      private

      def add_recurring(post, options)
        post[:recurring] = {}
        post[:recurring][:start_date] = options[:start_date].strftime('%Y-%m-%d')
        post[:recurring][:frequency] = options[:frequency]
        post[:recurring][:period] = options[:period]
        post[:recurring][:installments] = options[:installments]
        post[:recurring][:failureThreshold] = options[:failureThreshold] || 1
      end

    end
  end
end
