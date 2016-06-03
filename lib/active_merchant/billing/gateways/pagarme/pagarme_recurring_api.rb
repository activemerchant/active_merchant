require File.dirname(__FILE__) + '/helpers_pagarme.rb'
require File.dirname(__FILE__) + '/response_pagarme.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      include ActiveMerchant::Billing::PagarmeRecurringApi::HelpersPagarme
      include ActiveMerchant::Billing::PagarmeRecurringApi::ResponsePagarme

      def recurring(amount, credit_card, options = {})
        requires!(options, :payment_method)


        params = {
            payment_method: options[:payment_method],
            customer: ensure_customer_created(options),
            plan: ensure_plan_created(options[:plan_code], amount, options[:plan]),
            card_number: options[:card_number],
            card_holder_name: options[:card_holder_name],
            card_expiration_month: options[:card_expiration_month],
            card_expiration_year: options[:card_expiration_year],
            card_cvv: options[:card_cvv],
        }


        subscription = PagarMe::Subscription.new(params)

        if subscription.create
          Response.new(true, "Assinatura criada com sucesso")
        else
          Response.new(false, 'Erro ao criar assinatura', params)
        end

      end

      def update(invoice_id, options)
        requires!(options, :payment_method)

        subscription = PagarMe::Subscription.find_by_id(invoice_id)

        if options[:payment_method].present?
          subscription.payment_method = options[:payment_method]
        end

        if options[:plan_id].present?
          subscription.plan_id = options[:plan_id]
        end

        if options[:card_id].present?
          subscription.card_id = options[:card_id]
        end

        if options[:card_hash].present?
          subscription.card_hash = options[:card_hash]
        end

        if options[:card_number].present?
          subscription.card_number = options[:card_number]
        end

        if options[:card_holder_name].present?
          subscription.card_holder_name = options[:card_holder_name]
        end

        if options[:card_expiration_date].present? && expiration_date(options[:card_expiration_date])
          subscription.card_expiration_date = options[:card_expiration_date]
        end

        if subscription.save
          Response.new(true, "Assinatura alterada com sucesso")
        else
          Response.new(false, 'Erro ao alterar assinatura', options)
        end

      end

      def cancel(invoice_id)
        subscription = PagarMe::Subscription.find_by_id(invoice_id)

        if subscription.cancel
          Response.new(true, "Assinatura alterada com sucesso")
        else
          Response.new(false, 'Erro ao alterar assinatura', options)
        end

      end


      def invoice(invoice_id)
        response = PagarMe::Transaction.find_by_id(invoice_id)
        Response.new(true, nil, invoice_to_response(response))
      end


      def invoices(page, count)
        response = PagarMe::Transaction.all(page, count)
        Response.new(true, nil, {invoices: invoices_to_response(response)})
      end

      def payments(invoice_id)
        response = service_pagarme.payments_from_invoice(invoice_id)
        Response.new(true, nil, { payments: payments_to_response(response) })
      end

      def payment(invoice_id, payment_id)
        response = service_pagarme.payment_from_invoice(invoice_id, payment_id)
        Response.new(true, nil, payment_to_response(response))
      end

      def subscription_details(subscription_code)
        response = PagarMe::Subscription.find_by_id(subscription_code)
        Response.new(true, nil, subscription_response(response))

      end

      private

      def expiration_date(date)
        if /((1[0-2]|0[1-9])([0-9]){2})/ =~ date
          date
        else
          raise "Data de expiração do cartão com formato inválido"
        end
      end

      def ensure_customer_created(options)
        customer_response(PagarMe::Customer.find_by_id(options[:customer][:id]))
      rescue
        create_customer(options[:customer], options[:address])
      end

      def create_customer(customer, address)
        params = customer_params(customer, address)
        PagarMe::Customer.new(params).create
      end

      def ensure_plan_created(plan_code, amount, options)
        PagarMe::Plan.find_by_id(plan_code)
      rescue
        create_plan(options, amount)
      end

      def create_plan(params, amount)
        requires!(options, :name, :days)

        params = {
            :name => params[:name],
            :days => params[:days],
            :amount => amount,
        }
        PagarMe::Plan.new(params)
      end

    end
  end
end
