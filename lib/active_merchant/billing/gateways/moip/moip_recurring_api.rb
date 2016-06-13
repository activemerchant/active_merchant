module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MoipRecurringApi #:nodoc:
      INTERVAL_MAP = {
        'monthly' => ['MONTH', 1],
        'quarterly' => ['MONTH', 3],
        'semesterly' => ['MONTH', 6],
        'yearly' => ['YEAR', 1]
      }

      INVOICE_TO_SUBSCRIPTION_STATUS_MAP = {
        1 => :process,
        2 => :process,
        3 => :confirm,
        4 => :canceled,
        5 => :process
      }

      SUBSCRIPTION_STATUS_MAP = {
        'active'    => :confirm,
        'suspended' => :cancel,
        'expired'   => :process,
        'overdue'   => :process,
        'canceled'  => :cancel,
        'trial'     => :no_wait_process
      }

      INVOICE_STATUS_MAP = {
        1 => :open,
        2 => :wait_confirmation,
        3 => :confirm,
        4 => :not_pay,
        5 => :expire
      }

      PAYMENT_STATUS_MAP = {
        1 => :authorize,
        2 => :initiate,
        3 => :wait_boleto,
        4 => :confirm,
        5 => :cancel,
        6 => :wait_analysis,
        7 => :reverse,
        9 => :refund,
        10 => :wait_boleto
      }

      PAYMENT_METHOD_MAP = {
        1 => 'credit_card',
        2 => 'boleto'
      }

      def recurring(amount, credit_card, options = {})
        moip_plan_code = "PLAN-CODE-#{options[:subscription][:plan_code]}"

        cust = ensure_customer_created(options, credit_card)
        plan = ensure_plan_created(moip_plan_code, amount, options)

        params = {
          code: options[:transaction_id],
          plan: { code: moip_plan_code },
          amount: amount,
          customer: { code: customer_code(options) }
        }

        resp = Moip::Assinaturas::Subscription.create(params, false, moip_auth: moip_auth)

        if resp[:success]
          Response.new(resp[:success], resp[:subscription][:message],
            resp, test: test?, authorization: resp[:subscription][:code],
            subscription_action: subscription_action_from(resp),
            next_charge_at: next_charge_at(resp))
        else
          Response.new(resp[:success], resp[:message], resp)
        end
      end

      def invoices(subscription_code)
        response = Moip::Assinaturas::Invoice.list(subscription_code, moip_auth: moip_auth)
        Response.new(response[:success], nil, { invoices: invoices_to_response(response) }, test: test?)
      end

      def invoice(invoice_id)
        response = Moip::Assinaturas::Invoice.details(invoice_id, moip_auth: moip_auth)
        Response.new(response[:success], nil, invoice_to_response(response), test: test?)
      end

      def payments(invoice_id)
        response = Moip::Assinaturas::Payment.list(invoice_id, moip_auth: moip_auth)
        Response.new(response[:success], nil, { payments: payments_to_response(response) }, test: test?)
      end

      def payment(payment_id)
        response = Moip::Assinaturas::Payment.details(payment_id, moip_auth: moip_auth)
        Response.new(response[:success], nil, payment_to_response(response), test: test?)
      end

      def subscription_details(subscription_code)
        response = Moip::Assinaturas::Subscription.details(subscription_code, moip_auth: moip_auth)
        Response.new(response[:success], nil, response,
                     test: test?,
                     subscription_action: SUBSCRIPTION_STATUS_MAP[response[:subscription][:status].downcase],
                     next_charge_at: next_invoice_date(response[:subscription][:next_invoice_date]))
      end

      def cancel_recurring(subscription_code)
        response = Moip::Assinaturas::Subscription.cancel(subscription_code, moip_auth: moip_auth)
        Response.new(response[:success], nil, response, subscription_action: 'cancel',
          authorization: subscription_code,test: test?)
      end

      private

      def moip_auth
        { token: @options[:username], key: @options[:password], sandbox: test? }
      end

      def ensure_customer_created(options, credit_card)
        return if Moip::Assinaturas::Customer.details(customer_code(options),
                                                      moip_auth: moip_auth)[:success]

        create_customer(options[:customer], options[:address], credit_card)
      rescue
        create_customer(options[:customer], options[:address], credit_card)
      end

      def ensure_plan_created(moip_plan_code, amount, options)
        plan = Moip::Assinaturas::Plan.details(moip_plan_code, moip_auth: moip_auth)

        if plan[:success]
          try_update_plan(plan, moip_plan_code, amount, options[:subscription])
        else
          create_plan(moip_plan_code, amount, options[:subscription])
        end
      rescue
        create_plan(moip_plan_code, amount, options[:subscription])
      end

      def create_customer(customer, address, credit_card)
        cpf = customer[:legal_identifier].gsub('.', '').gsub('-', '')
        phone = customer[:phone].gsub(/\(|\)|\-|\.|\s/, '')

        Moip::Assinaturas::Customer.create({
          code: "ED#{customer[:id]}",
          email: customer[:email],
          fullname: customer[:name],
          cpf: cpf,
          phone_area_code: phone[0..1],
          phone_number: phone[2..-1],
          birthdate_day: customer[:born_at].day,
          birthdate_month: customer[:born_at].month,
          birthdate_year: customer[:born_at].year,
          address: {
            street: address[:street],
            number: address[:number],
            complement: address[:complement],
            district: address[:district],
            city: address[:city],
            state: address[:state],
            country: "BRA",
            zipcode: address[:zip_code]
          },
          billing_info: {
            credit_card: {
              holder_name: credit_card.name,
              number: credit_card.number,
              expiration_month: credit_card.month,
              expiration_year: credit_card.year - 2000
            }
          }
        }, true, moip_auth: moip_auth)
      end

      def try_update_plan(moip_plan, moip_plan_code, amount, subscription)
        plan_attributes = plan_params(moip_plan_code, amount, subscription)

        if plan_changed?(moip_plan[:plan], plan_attributes)
          response = Moip::Assinaturas::Plan.update(plan_attributes, moip_auth: moip_auth)

          if response[:success]
            Moip::Assinaturas::Plan.details(moip_plan_code, moip_auth: moip_auth)
          else
            plan
          end
        else
          plan
        end
      end

      def plan_changed?(plan, plan_attributes)
        plan['amount']             != plan_attributes[:amount]            ||
        plan['interval']['unit']   != plan_attributes[:interval][:unit]   ||
        plan['interval']['length'] != plan_attributes[:interval][:length] ||
        plan['trial']['days']      != plan_attributes[:trial][:days]      ||
        plan['trial']['enabled']   != plan_attributes[:trial][:enabled]   ||
        plan['billing_cycles']     != plan_attributes[:billing_cycles]
      end

      def create_plan(moip_plan_code, amount, subscription)
        Moip::Assinaturas::Plan.create(plan_params(moip_plan_code, amount, subscription),
          moip_auth: moip_auth)
      end

      def plan_params(moip_plan_code, amount, subscription)
        unit, length = INTERVAL_MAP[subscription[:period]]

        plan_attributes = {
          code: moip_plan_code,
          name: "ONE INVOICE FOR #{length} #{unit} #{moip_plan_code}",
          description: 'PLAN USED TO CREATE SUBSCRIPTIONS BY EDOOLS',
          amount: amount,
          status: 'ACTIVE',
          interval: {
            unit: unit,
            length: length
          },
          trial: {
            days: subscription[:trials],
            enabled: subscription[:trials].present? && subscription[:trials] > 0
          }
        }

        plan_attributes[:billing_cycles] = subscription[:cycles] if subscription[:cycles]

        plan_attributes
      end

      def customer_code(options)
        @customer_code ||= "ED#{options[:customer][:id]}"
      end

      def subscription_action_from(response)
        return :fail unless response[:success]

        INVOICE_TO_SUBSCRIPTION_STATUS_MAP[response[:subscription][:invoice][:status][:code]]
      end

      def next_charge_at(response)
        return nil unless response[:success]

        Date.new(response[:subscription][:next_invoice_date][:year],
                 response[:subscription][:next_invoice_date][:month],
                 response[:subscription][:next_invoice_date][:day])
      end

      def invoices_to_response(response)
        return {} unless response[:success]

        response[:invoices].map do |invoice|
          {
            'id' => invoice[:id],
            'amount' => invoice[:amount],
            'created_at' => created_at(invoice[:creation_date]),
            'action' => INVOICE_STATUS_MAP[invoice[:status][:code]],
            'occurrence' => invoice[:occurrence]
          }
        end
      end

      def invoice_to_response(response)
        return {} unless response[:success]

        {
          'id' => response[:invoice][:id],
          'amount' => response[:invoice][:amount],
          'created_at' => created_at(response[:invoice][:creation_date]),
          'action' => INVOICE_STATUS_MAP[response[:invoice][:status][:code]],
          'occurrence' => response[:invoice][:occurrence]
        }
      end

      def created_at(creation_date)
        DateTime.new(creation_date[:year], creation_date[:month], creation_date[:day],
                     creation_date[:hour], creation_date[:minute], creation_date[:second], '-03:00')
      end

      def payments_to_response(response)
        return {} unless response[:success]

        response[:payments].map do |payment|
          {
            'id' => payment[:id],
            'created_at' => created_at(payment[:creation_date]),
            'action' => PAYMENT_STATUS_MAP[payment[:status][:code]],
            'payment_method' => PAYMENT_METHOD_MAP[payment[:payment_method][:code]]
          }
        end
      end

      def payment_to_response(response)
        return {} unless response[:success]

        payment = response[:payment]

        {
          'id' => payment[:id],
          'created_at' => created_at(payment[:creation_date]),
          'action' => PAYMENT_STATUS_MAP[payment[:status][:code]],
          'payment_method' => PAYMENT_METHOD_MAP[payment[:payment_method][:code]]
        }
      end

      def next_invoice_date(invoice_date)
        DateTime.new(invoice_date[:year], invoice_date[:month], invoice_date[:day], 0, 0, 0, '-03:00')
      end
    end
  end
end
