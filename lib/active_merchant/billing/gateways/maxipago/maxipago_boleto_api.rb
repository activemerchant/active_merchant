require 'active_merchant/billing/gateways/maxipago/maxipago_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in MaxipagoGateway
    module MaxipagoBoletoAPI
      def generate_boleto(amount, options = {})
        options[:amount] = amount
        requires!(options, :expiration_date, :number, :amount)

        post = {}
        add_aux_data(post, options)
        add_amount(post, amount)
        add_payer_name(post, options)
        add_address(post, options)
        add_boleto(post, options)

        commit(build_sale_request(post))
      end

      def manual_boleto_number?
        true
      end

      def generate_boleto_number(processor_id)
        digits = processor_itau?(processor_id) ? 8 : 10
        limit = 10 ** digits
        number = Random.rand(limit)
        "%0#{digits}d" % number
      end

      private

      def add_boleto(post, options)
        post[:payment_type] = :boleto
        post[:expiration_date] = options[:expiration_date].strftime('%Y-%m-%d')
        post[:number] = options[:number] || generate_boleto_number(options[:processor_id])
        post[:instructions] = options[:instructions] if options[:instructions]
      end

      def processor_itau?(processor_id)
        processor_id == 11
      end

    end
  end
end
