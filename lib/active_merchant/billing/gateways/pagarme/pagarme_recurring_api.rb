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

        params = {
            payment_method: options[:payment_method],
            customer: ensure_customer_created(options, credit_card),
            plan: ensure_plan_created(options[:card_hash], amount, options[:plan])
        }

        puts params
        #
        # resp = PagarMe::Subscription.new(params)
        # subscription.create
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

      private

      def ensure_customer_created(options, credit_card)
          return if PagarMe::Customer.find_by_id(options[:customer][:id])

          create_customer(options[:customer], options[:address], credit_card)
        rescue
          create_customer(options[:customer], options[:address], credit_card)
      end

      def create_customer(customer, address, credit_card)

        params = {
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
        plan = PagarMe::Plan.find_by_id(plan_code)

        if plan
          try_update_plan(plan, plan_code, amount, options[:subscription])
        else
          create_plan(options, amount)
        end
      rescue
        create_plan(options, amount)
      end

      def create_plan(params, amount, subscription)
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
