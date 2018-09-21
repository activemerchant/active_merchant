require 'active_merchant/billing/gateways/beanstream/beanstream_core'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BeanstreamDefautGateway < Gateway
      include BeanstreamCore

      def initialize(options = {})
        requires!(options, :login)

        super
      end

      def authorize(money, source, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_source(post, source)
        add_address(post, options)
        add_transaction_type(post, :authorization)
        add_customer_ip(post, options)
        add_recurring_payment(post, options)
        commit(post)
      end

      def purchase(money, source, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_source(post, source)
        add_address(post, options)
        add_transaction_type(post, purchase_action(source))
        add_customer_ip(post, options)
        add_recurring_payment(post, options)
        commit(post)
      end

      def capture(money, authorization, options = {})
        reference, = split_auth(authorization)

        post = {}
        add_amount(post, money)
        add_reference(post, reference)
        add_transaction_type(post, :capture)
        add_recurring_payment(post, options)
        commit(post)
      end

      def refund(money, source, _options = {})
        post = {}
        reference, _, type = split_auth(source)
        add_reference(post, reference)
        add_transaction_type(post, refund_action(type))
        add_amount(post, money)
        commit(post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(Authorization: Basic )\w+/, '\1[FILTERED]')
          .gsub(/(&?password=)[^&\s]*(&?)/, '\1[FILTERED]\2')
          .gsub(/(&?trnCardCvd=)\d*(&?)/, '\1[FILTERED]\2')
          .gsub(/(&?trnCardNumber=)\d*(&?)/, '\1[FILTERED]\2')
      end

      def void(authorization, _options = {})
        reference, amount, type = split_auth(authorization)

        post = {}
        add_reference(post, reference)
        add_original_amount(post, amount)
        add_transaction_type(post, void_action(type))
        commit(post)
      end

      def verify(source, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, source, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def success?(response)
        response[:trnApproved] == '1' || response[:responseCode] == '1'
      end

      def recurring(money, source, options = {})
        ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, source)
        add_address(post, options)
        add_transaction_type(post, purchase_action(source))
        add_recurring_type(post, options)
        commit(post)
      end

      def update_recurring(amount, source, options = {})
        ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

        post = {}
        add_recurring_amount(post, amount)
        add_recurring_invoice(post, options)
        add_credit_card(post, source)
        add_address(post, options)
        add_recurring_operation_type(post, :update)
        add_recurring_service(post, options)
        recurring_commit(post)
      end

      def cancel_recurring(options = {})
        ActiveMerchant.deprecated RECURRING_DEPRECATION_MESSAGE

        post = {}
        add_recurring_operation_type(post, :cancel)
        add_recurring_service(post, options)
        recurring_commit(post)
      end

      def interac
        @interac ||= BeanstreamInteracGateway.new(@options)
      end

      # To match the other stored-value gateways, like TrustCommerce,
      # store and unstore need to be defined
      def store(payment_method, options = {})
        post = {}
        add_address(post, options)

        if payment_method.respond_to?(:number)
          add_credit_card(post, payment_method)
        else
          post[:singleUseToken] = payment_method
        end
        add_secure_profile_variables(post, options)

        commit(post, true)
      end

      # can't actually delete a secure profile with the supplicated API. This function sets the status of the profile to closed (C).
      # Closed profiles will have to removed manually.
      def delete(vault_id)
        update(vault_id, false, status: 'C')
      end

      alias unstore delete

      # Update the values (such as CC expiration) stored at
      # the gateway.  The CC number must be supplied in the
      # CreditCard object.
      def update(vault_id, payment_method, options = {})
        post = {}
        add_address(post, options)
        if payment_method.respond_to?(:number)
          add_credit_card(post, payment_method)
        else
          post[:singleUseToken] = payment_method
        end
        options[:vault_id] = vault_id
        options[:operation] = secure_profile_action(:modify)
        add_secure_profile_variables(post, options)
        commit(post, true)
      end

      private

      def build_response(*args)
        Response.new(*args)
      end
    end
  end
end
