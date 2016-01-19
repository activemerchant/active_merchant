require 'active_merchant/billing/gateways/maxipago/maxipago_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in MaxipagoGateway
    module MaxipagoBoletoAPI
      def generate_boleto(amount, options = {})
        options[:amount] = amount
        requires!(options, :amount)

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
        expiration_days = options[:boleto][:expiration_days] || 3
        post[:expiration_date] = (Time.now + expiration_days.days).strftime('%Y-%m-%d')
        post[:number] = options[:boleto][:number] || generate_boleto_number(options[:extras][:boleto_processor_id])

        instructions = ''
        instructions = "#{options[:extras][:instruction_line_1]}"   if options[:extras][:instruction_line_1]
        instructions = "\n#{options[:extras][:instruction_line_2]}" if options[:extras][:instruction_line_2]
        instructions = "\n#{options[:extras][:instruction_line_3]}" if options[:extras][:instruction_line_3]

        post[:instructions] = instructions if instructions
      end

      def processor_itau?(processor_id)
        processor_id == 11
      end

    end
  end
end
