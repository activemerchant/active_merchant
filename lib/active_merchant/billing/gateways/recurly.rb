#
# Move that class to activemerchant gem
#
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RecurlyGateway < Gateway
      preference :api_key,   :string
      preference :subdomain, :string
      preference :currency,  :string, :default => 'USD'

      attr_accessible :preferred_api_key, :preferred_subdomain, :preferred_currency

      after_find :update_recurly_config

      def provider_class
        self.class
      end

      def payment_profiles_supported?
        true
      end

      # Recurly doesn't support authorize
      def authorize(amount, creditcard, gateway_options)
        raise "Recurly doesn't support authorize"
      end

      def purchase(amount, creditcard, gateway_options)
        create_transaction(amount, creditcard, gateway_options)
      end

      # Recurly doesn't support capture
      def capture(authorization, creditcard, gateway_options)
        raise "Recurly doesn't support capture"
      end

      def credit(amount, creditcard, response_code, gateway_options)
        transaction = Recurly::Transaction.find(response_code)
        transaction.refund(amount)

        if transaction.status == 'success'
          message = 'refund success!'
        else
          message = 'refund failed!'
        end

        ActiveMerchant::Billing::Response.new(transaction.status == 'success', message, {},
          :authorization => transaction.uuid,
          :avs_result => {:street_match => transaction.avs_result }
        )
      end

      def void(response_code, creditcard, gateway_options)
        transaction = Recurly::Transaction.find(response_code)

        if transaction.refund
          message = 'void success!'
        else
          message = 'void failed!'
        end

        ActiveMerchant::Billing::Response.new(transaction.status == 'void', message, {},
          :authorization => transaction.uuid,
          :avs_result => {:street_match => transaction.avs_result }
        )
      end

      def create_profile(payment)
        return unless payment.source.gateway_customer_profile_id.nil?

        begin
          account = Recurly::Account.find(payment.order.user_id)
          account.billing_info = billing_info_for(payment).merge(address_info_for(payment))
          account.billing_info.save
        rescue Recurly::Resource::NotFound => e
          account = Recurly::Account.create(
            :account_code => payment.order.user_id,
            :email        => payment.order.email,
            :first_name   => payment.order.bill_address.try(:firstname),
            :last_name    => payment.order.bill_address.try(:lastname),
            :address      => address_info_for(payment),
            :billing_info => billing_info_for(payment)
          )
        end

        if account.errors.present?
          payment.send(:gateway_error, account.errors.full_messages.join('. '))
        else
          payment.source.update_attributes!(:gateway_customer_profile_id => account.account_code)
        end

      rescue Recurly::Transaction::Error => e
        payment.send(:gateway_error, e.message)
      end

      private

      def update_recurly_config
        Recurly.subdomain        =  preferred_subdomain
        Recurly.api_key          =  preferred_api_key
        Recurly.default_currency =  preferred_currency
      end

      # Create a transaction on a creditcard
      def create_transaction(amount, creditcard, options = {})
        account = Recurly::Account.find(creditcard.gateway_customer_profile_id)

        transaction = account.transactions.create(
          :amount_in_cents => amount,
          :currency        => preferred_currency
        )

        if transaction.errors
          message = transaction.errors.full_messages.join('. ')
        else
          message = 'transaction success!'
        end

        ActiveMerchant::Billing::Response.new(transaction.status == 'success', message, {},
          :authorization => transaction.uuid,
          :avs_result => {:street_match => transaction.avs_result }
        )
      end

      def address_info_for(payment)
        address = payment.order.bill_address

        info = {
          address1: address.address1,
          address2: address.address2,
          city: address.city,
          zip: address.zipcode
        }

        if country = address.country
          info.merge!(country: country.name)
        end

        if state = address.state
          info.merge!(state: state.name)
        end

        info
      end

      def billing_info_for(payment)
        address = payment.order.bill_address
        card    = payment.source

        info = {
          first_name: address.firstname,
          last_name:  address.lastname,
          address1:   address.address1,
          address2:   address.address2,
          city:       address.city,
          zip:        address.zipcode,
          number:     card.number,
          month:      card.month,
          year:       card.year,
          verification_value: card.verification_value
        }

        if country = address.country
          info.merge!(country: country.name)
        end

        if state = address.state
          info.merge!(state: state.name)
        end

        info
      end
    end
  end
end
