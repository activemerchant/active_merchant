module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:

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
        #
        # if resp[:success]
        #   Response.new(resp[:success], resp[:subscription][:message],
        #                resp, test: test?, authorization: resp[:subscription][:code],
        #                subscription_action: subscription_action_from(resp),
        #                next_charge_at: next_charge_at(resp))
        # else
        #   Response.new(resp[:success], resp[:message], resp)
        # end

      end

      def invoice(invoice_id)
        PagarMe::Subscription.find_by_id("14858")
      end

      private

      def ensure_customer_created(options)
        toCustomerResponse(PagarMe::Customer.find_by_id(options[:customer][:id]))
      rescue
        create_customer(options[:customer], options[:address])
      end

      def toCustomerResponse(customer)
        {
            :document_number => customer.document_number,
            :name => customer.name,
            :email => customer.email,
            :address => {
                :street => customer.addresses[0].street,
                :complementary => customer.addresses[0].complementary,
                :street_number => customer.addresses[0].street_number,
                :neighborhood => customer.addresses[0].neighborhood,
                :city => customer.addresses[0].city,
                :state => customer.addresses[0].state,
                :zipcode => customer.addresses[0].zipcode,
                :country => "Brasil"
            },
            :phone => {
                :ddi => customer.phones[0].ddi,
                :ddd => customer.phones[0].ddd,
                :number => customer.phones[0].number
            }
        }
      end

      def create_customer(customer, address)

        params = {
            :document_number => customer[:document_number],
            :name => customer[:name],
            :email => customer[:email],
            :address => {
                :street => address[:street],
                :complementary => address[:complement],
                :street_number => address[:number],
                :neighborhood => address[:district],
                :city => address[:city],
                :state => address[:state],
                :zipcode => address[:zipcode],
                :country => "Brasil"
            },
            :phone => {
                :ddi => customer[:ddi],
                :ddd => customer[:ddd],
                :number => customer[:number]
            }
        }
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
