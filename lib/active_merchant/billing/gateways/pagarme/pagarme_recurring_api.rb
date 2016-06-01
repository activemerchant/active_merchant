require File.dirname(__FILE__) + '/helpers_pagarme.rb'
require File.dirname(__FILE__) + '/response_pagarme.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      include ActiveMerchant::Billing::PagarmeRecurringApi::HelpersPagarme
      include ActiveMerchant::Billing::PagarmeRecurringApi::ResponsePagarme

      SUBSCRIPTION_STATUS_MAP = {
          'ended' => :ended,
          'canceled' => :canceled,
          'unpaid' => :unpaid,
          'pending_payment' => :pending_payment,
          'paid' => :paid,
          'trialing' => :trialing
      }

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

      def invoice(invoice_id)
        response = PagarMe::Subscription.find_by_id(invoice_id)
        Response.new(true, nil, invoice_to_response(response))
      end


      def invoices(page, count)
        response = PagarMe::Subscription.all(page, count)
        Response.new(true, nil, {invoices: invoices_to_response(response)})
      end

      private

      def ensure_customer_created(options)
        customerResponse(PagarMe::Customer.find_by_id(options[:customer][:id]))
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
