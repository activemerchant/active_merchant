require File.dirname(__FILE__) + '/moip_status'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MoipRecurringApi #:nodoc:
      include MoipStatus

      def create_plan(plan_params)
        params = plan_params(plan_params)

        if plan_params[:plan_code]
          code = "PLAN-CODE-#{plan_params[:plan_code]}"
          params[:code] = code.gsub("-", "").gsub(".", "")
        end

        begin
          moip_response = Moip::Assinaturas::Plan.create(params, moip_auth: moip_auth)
          moip_response[:code] = params[:code]

          build_response_plan(moip_response)
        rescue Moip::Assinaturas::WebServerResponseError => error
          build_response_plan(error)
        end
      end

      def find_plan(plan_code)
        plan_code = '9XQZVK' if plan_code.nil?

        moip_response = Moip::Assinaturas::Plan.details(plan_code, moip_auth: moip_auth)
        build_response_plan(moip_response)
      end

      def update_plan(params)
        begin
          plan_attributes = plan_params(params)
          moip_response   = find_plan(plan_attributes[:code])
          plan            = moip_response.params['plan']

          plan_attributes.delete(:interval)
          plan_attributes[:amount] = plan['amount']

          moip_response    = Moip::Assinaturas::Plan.update(plan_attributes, moip_auth: moip_auth)
          success, message = [true, 'Plano atualizado com sucesso.']

          Response.new(success, message, moip_response, test: test?, plan_code: plan_code_from(params))
        rescue Moip::Assinaturas::WebServerResponseError => error
          build_response_plan(error)
        end
      end

      def recurring(amount, credit_card, options = {})
        begin
          cust = ensure_customer_created(options, credit_card)

          params = {
            code: options[:transaction_id],
            plan: { code: options[:subscription][:plan_code] },
            amount: amount,
            customer: { code: customer_code(options) }
          }

          resp = Moip::Assinaturas::Subscription.create(params, false, moip_auth: moip_auth)

          if resp[:success]
            Response.new(resp[:success], resp[:subscription][:message],
            resp, test: test?, authorization: resp[:subscription][:code],
            subscription_action: subscription_action_from(resp),
            next_charge_at: next_charge_at(resp), invoice_id: invoice_id_from(resp))
          else
            Response.new(resp[:success], resp[:message], resp)
          end
        rescue Moip::Assinaturas::WebServerResponseError => error
          build_response_error(error)
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

      def last_payment_from_invoice(invoice_id)
        response     = Moip::Assinaturas::Payment.list(invoice_id, moip_auth: moip_auth)
        last_payment = response[:payments].last
        last_code    = last_payment['status']['code']
        options      = {
          test: test?,
          payment_action: PAYMENT_STATUS_MAP[last_code]
        }

        Response.new(response[:success], nil, payment_to_response(last_payment), options)
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

      def build_response_plan(response)
        if response.try(:[], :success)
          Response.new(response[:success], response[:plan][:message],
            response, test: test?, plan_code: plan_code_from(response))
        else
          build_response_error(response)
        end
      end

      def invoice_id_from(response)
        response && response[:subscription] && response[:subscription]['invoice']['id']
      end

      def plan_code_from(response)
         response && response["code"] || response[:code] || response[:plan_code] || nil
      end

      def build_response_error(response)
        if response.try(:message)
          response = JSON.parse(response.message)

          Response.new(false, response["ERROR"], response, test: test?)
        else
          Response.new(false, response[:errors].to_s, response, test: test?)
        end
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

      def plan_params(params)
        unit, length = INTERVAL_MAP[params[:period]]

        plan_attributes = {
          name: "ONE INVOICE FOR #{length} #{unit} #{params[:plan_code]}",
          description: 'PLAN USED TO CREATE SUBSCRIPTIONS BY EDOOLS',
          amount: params[:price],
          status: 'ACTIVE',
            interval: {
              unit: unit,
              length: length
            },
            trial: {
              days: params[:trials],
              enabled: params[:trials].present? && params[:trials] > 0
            }
          }

          plan_attributes[:setup_fee] = params[:fee] if params[:fee]
          plan_attributes[:code] = params[:plan_code] if params[:plan_code]
          plan_attributes[:trial][:hold_setup_fee] = params[:hold_setup_fee] if params[:hold_setup_fee]
          plan_attributes[:payment_method] = params[:payment_method] if params[:payment_method]
          plan_attributes[:billing_cycles] = params[:cycles] if params[:cycles]

          plan_attributes
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
