require 'active_merchant/billing/gateways/beanstream/beanstream_core'
require 'active_merchant/billing/gateways/beanstream/ipp_core'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This class implements the Canadian {Beanstream}[http://www.beanstream.com] payment gateway.
    # It is also named TD Canada Trust Online Mart payment gateway.
    # To learn more about the specification of Beanstream gateway, please read the OM_Direct_Interface_API.pdf,
    # which you can get from your Beanstream account or get from me by email.
    #
    # == Supported transaction types by Beanstream:
    # * +P+ - Purchase
    # * +PA+ - Pre Authorization
    # * +PAC+ - Pre Authorization Completion
    #
    # == Secure Payment Profiles:
    # BeanStream supports payment profiles (vaults). This allows you to store cc information with BeanStream and process subsequent transactions with a customer id.
    # Secure Payment Profiles must be enabled on your account (must be done over the phone).
    # Your API Access Passcode must be set in Administration => account settings => order settings.
    # To learn more about storing credit cards with the Beanstream gateway, documentation can be found at http://developer.beanstream.com/documentation/classic-apis
    #
    # To store a credit card using Beanstream's Legato Javascript Library (http://developer.beanstream.com/documentation/legato) you must pass the singleUseToken in
    # the store method's option parameter. Example: @gateway.store("gt6-0c78c25b-3637-4ba0-90e2-26105287f198")
    #
    # == Notes
    # * Adding of order products information is not implemented.
    # * Ensure that country and province data is provided as a code such as "CA", "US", "QC".
    # * login is the Beanstream merchant ID, username and password should be enabled in your Beanstream account and passed in using the <tt>:user</tt> and <tt>:password</tt> options.
    # * Test your app with your true merchant id and test credit card information provided in the api pdf document.
    # * Beanstream does not allow Payment Profiles to be deleted with their API. The accounts are 'closed', but have to be deleted manually.
    #
    #  Example authorization (Beanstream PA transaction type):
    #
    #   twenty = 2000
    #   gateway = BeanstreamGateway.new(
    #     :login => '100200000',
    #     :user => 'xiaobozz',
    #     :password => 'password'
    #   )
    #
    #   credit_card = CreditCard.new(
    #     :number => '4030000010001234',
    #     :month => 8,
    #     :year => 2011,
    #     :first_name => 'xiaobo',
    #     :last_name => 'zzz',
    #     :verification_value => 137
    #   )
    #   response = gateway.authorize(twenty, credit_card,
    #     :order_id => '1234',
    #     :billing_address => {
    #       :name => 'xiaobo zzz',
    #       :phone => '555-555-5555',
    #       :address1 => '1234 Levesque St.',
    #       :address2 => 'Apt B',
    #       :city => 'Montreal',
    #       :state => 'QC',
    #       :country => 'CA',
    #       :zip => 'H2C1X8'
    #     },
    #     :email => 'xiaobozzz@example.com',
    #     :subtotal => 800,
    #     :shipping => 100,
    #     :tax1 => 100,
    #     :tax2 => 100,
    #     :custom => 'reference one'
    #   )
    #
    # Modification on 2018-03-12:
    # New feature: integrated the ipp gateway into beanstream gateway, use this class as an unified entrance for both the gateways
    # Get the :region field from options parameter, :region: 0 - US & CA, 1 - AU
    # Proess payment request from US & CA using beanstream service (default)
    # Proess payment request from AU using ipp service
    # Will remove ipp gateway file
    #

    class BeanstreamGateway < Gateway
      attr_accessor :region
      include Empty

      # Only <tt>:login</tt> is required by default,
      # which is the merchant's merchant ID. If you'd like to perform void,
      # capture or refund transactions then you'll also need to add a username
      # and password to your account under administration -> account settings ->
      # order settings -> Use username/password validation
      def initialize(options = {})
        #region: 0 - US & CA, 1 - AU & NZ
        @region = empty?(options[:region]) ? 0 : options[:region]

        # I want to add this logic to judge the region from shipping & billing address
        # but don't know if it is a correct way.
        # I think this can be decided by shopify which will integrate with.

        # [ options[:billing_address], options[:shipping_address] ].compact.each do |address|
        #   next if empty?(address[:country])
        #   unless ['AU', 'NZ'].include?(address[:country])
        #     @region = 1
        #   end
        # end

        if @region == 1
          include_ipp
          requires!(options, :username, :password, :login)
        else
          include_beanstream
          requires!(options, :login)
        end
        
        super
      end

      def authorize(money, source, options = {})
        if @region == 1
          ipp_authorize(money, source, options)
        else
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
      end

      def purchase(money, source, options = {})
        if @region == 1
          ipp_purchase(money, source, options)
        else
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
      end

      def capture(money, authorization, options = {})
        if @region == 1
          ipp_capture(money, authorization, options)
        else
          reference, _, _ = split_auth(authorization)

          post = {}
          add_amount(post, money)
          add_reference(post, reference)
          add_transaction_type(post, :capture)
          add_recurring_payment(post, options)
          commit(post)
        end
      end

      def refund(money, source, options = {})
        if @region == 1
          ipp_refund(money, source, options)
        else
          post = {}
          reference, _, type = split_auth(source)
          add_reference(post, reference)
          add_transaction_type(post, refund_action(type))
          add_amount(post, money)
          commit(post)
        end
      end

      def supports_scrubbing?
        if @region == 1
          ipp_supports_scrubbing?
        else
          true
        end
      end

      def scrub(transcript)
        if @region == 1
          ipp_scrub(transcript)
        else
          transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(/(&?password=)[^&\s]*(&?)/, '\1[FILTERED]\2').
          gsub(/(&?trnCardCvd=)\d*(&?)/, '\1[FILTERED]\2').
          gsub(/(&?trnCardNumber=)\d*(&?)/, '\1[FILTERED]\2')
        end
      end

      def void(authorization, options = {})
        reference, amount, type = split_auth(authorization)

        post = {}
        add_reference(post, reference)
        add_original_amount(post, amount)
        add_transaction_type(post, void_action(type))
        commit(post)
      end

      def verify(source, options={})
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

      #can't actually delete a secure profile with the supplicated API. This function sets the status of the profile to closed (C).
      #Closed profiles will have to removed manually.
      def delete(vault_id)
        update(vault_id, false, {:status => "C"})
      end

      alias_method :unstore, :delete

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
        options.merge!({:vault_id => vault_id, :operation => secure_profile_action(:modify)})
        add_secure_profile_variables(post,options)
        commit(post, true)
      end

      private
      def include_ipp
        BeanstreamGateway.include IPPCore
      end

      def include_beanstream
        BeanstreamGateway.include BeanstreamCore
      end
      
      def build_response(*args)
        Response.new(*args)
      end
    end
  end
end
