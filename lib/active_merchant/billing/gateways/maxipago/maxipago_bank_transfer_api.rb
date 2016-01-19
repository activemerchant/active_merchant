require 'active_merchant/billing/gateways/maxipago/maxipago_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in MaxipagoGateway
    module MaxipagoBankTransferAPI
      def bank_transfer(amount, options = {})
        options[:amount] = amount
        options[:customer_identifier] = options[:customer][:legal_identifier]
        options[:url_params] = URI(options[:extras][:return_url]).query
        requires!(options, :customer_identifier, :amount, :url_params)

        post = {}
        add_aux_data(post, options)
        add_amount(post, amount)
        add_payer_name(post, options)
        add_address(post, options)
        add_bank_transfer(post, options)

        commit(build_sale_request(post))
      end

      private

      def add_bank_transfer(post, options)
        post[:payment_type] = :bank_transfer
        post[:customer_identifier] = options[:customer_identifier]
        post[:url_params] = options[:url_params]
      end

    end
  end
end
