
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    require 'authorizenet'
    require File.dirname(__FILE__) + '/authorize_net/authorize_net_core'
    require File.dirname(__FILE__) + '/authorize_net/authorize_net_arb'
    # For more information on the Authorize.Net Gateway please visit their {Integration Center}[http://developer.authorize.net/]
    #
    # The login and password are not the username and password you use to
    # login to the Authorize.Net Merchant Interface. Instead, you will
    # use the API Login ID as the login and Transaction Key as the
    # password.
    #
    # ==== How to Get Your API Login ID and Transaction Key
    #
    # 1. Log into the Merchant Interface
    # 2. Select Settings from the Main Menu
    # 3. Click on API Login ID and Transaction Key in the Security section
    # 4. Type in the answer to the secret question configured on setup
    # 5. Click Submit
    #
    # ==== Automated Recurring Billing (ARB)
    #
    # Automated Recurring Billing (ARB) is an optional service for submitting and managing recurring, or subscription-based, transactions.
    #
    # To use recurring, update_recurring, cancel_recurring and status_recurring ARB must be enabled for your account.
    #
    # Information about ARB is available on the {Authorize.Net website}[http://www.authorize.net/solutions/merchantsolutions/merchantservices/automatedrecurringbilling/].
    # Information about the ARB API is available at the {Authorize.Net Integration Center}[http://developer.authorize.net/]
    class AuthorizeNetXmlGateway < Gateway
      include AuthorizeNetCore
      include AuthorizeNetArb
      API_VERSION = '4.0'

      class_attribute :arb_test_url, :arb_live_url

      self.test_url = "https://test.authorize.net/gateway/transact.dll"
      self.live_url = "https://secure.authorize.net/gateway/transact.dll"

      self.arb_test_url = 'https://apitest.authorize.net/xml/v1/request.api'
      self.arb_live_url = 'https://api.authorize.net/xml/v1/request.api'

      class_attribute :duplicate_window, :partial_test_mode

      self.partial_test_mode = false;

      # Creates a new AuthorizeNetGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The Authorize.Net API Login ID (REQUIRED)
      # * <tt>:password</tt> -- The Authorize.Net Transaction Key. (REQUIRED)
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test server.
      #   Otherwise, perform transactions against the production server.
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      # Performs an authorization, which reserves the funds on the customer's credit card, but does not
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>paysource</tt> -- The CreditCard or Check details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, paysource, options = {})
        transaction = get_transaction
        add_currency_code(transaction, money, options)
        add_invoice(transaction, options)

        add_address(transaction, options)
        add_customer_data(transaction, options)
        add_duplicate_window(transaction)

        anet_payment_source = get_payment_source(paysource, options)
        anet_response = transaction.authorize(money, anet_payment_source)
        build_active_merchant_response(anet_response)
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>paysource</tt> -- The CreditCard or Check details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, paysource, options = {})
        transaction = get_transaction
        add_currency_code(transaction, money, options)
        add_invoice(transaction, options)
        add_address(transaction, options)
        add_customer_data(transaction, options)
        add_duplicate_window(transaction)

        anet_payment_source = get_payment_source(paysource, options)
        anet_response = transaction.purchase(money, anet_payment_source)
        build_active_merchant_response(anet_response)
      end

      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      def capture(money, authorization, options = {})
        transaction = get_transaction
        add_customer_data(transaction, options)
        add_invoice(transaction, options)

        anet_response = transaction.prior_auth_capture(authorization, money)
        build_active_merchant_response(anet_response)
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
      def void(authorization, options = {})
        transaction = get_transaction
        add_duplicate_window(transaction)
        anet_response = transaction.void(authorization)
        build_active_merchant_response(anet_response)
      end

      # Refund a transaction.
      #
      # This transaction indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>identification</tt> -- The ID of the original transaction against which the refund is being issued.
      # * <tt>credit_clard</tt> -- The ActiveMerchant::Billing::CreditCard used in the original transaction against which the refund is being issued.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:card_number</tt> -- The credit card number the refund is being issued to. (REQUIRED)
      #   You can either pass the last four digits of the card number or the full card number.
      # * <tt>:first_name</tt> -- The first name of the account being refunded.
      # * <tt>:last_name</tt> -- The last name of the account being refunded.
      # * <tt>:zip<l/tt> -- The postal code of the account being refunded.
      def refund(money, identification, credit_card, options = {})
        transaction = get_transaction

        add_invoice(transaction, options)
        add_duplicate_window(transaction)

        anet_payment_source = get_payment_source(credit_card)
        anet_response = transaction.refund(money, identification, anet_payment_source)
        build_active_merchant_response(anet_response)
      end

      def credit(money, identification, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      # Create a recurring payment.
      #
      # This transaction creates a new Automated Recurring Billing (ARB) subscription. Your account must have ARB enabled.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be charged to the customer at each interval as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:interval</tt> -- A hash containing information about the interval of time between payments. Must
      #   contain the keys <tt>:length</tt> and <tt>:unit</tt>. <tt>:unit</tt> can be either <tt>:months</tt> or <tt>:days</tt>.
      #   If <tt>:unit</tt> is <tt>:months</tt> then <tt>:length</tt> must be an integer between 1 and 12 inclusive.
      #   If <tt>:unit</tt> is <tt>:days</tt> then <tt>:length</tt> must be an integer between 7 and 365 inclusive.
      #   For example, to charge the customer once every three months the hash would be
      #   +:interval => { :unit => :months, :length => 3 }+ (REQUIRED)
      # * <tt>:duration</tt> -- A hash containing keys for the <tt>:start_date</tt> the subscription begins (also the date the
      #   initial billing occurs) and the total number of billing <tt>:occurrences</tt> or payments for the subscription. (REQUIRED)
      def recurring(money, creditcard, options={})
        requires!(options, :interval, :duration, :billing_address)
        requires!(options[:interval], :length, [:unit, :days, :months])
        requires!(options[:duration], :start_date, :occurrences)
        requires!(options[:billing_address], :first_name, :last_name)

        options[:credit_card] = creditcard
        options[:amount] = money

        transaction = get_recurring_transaction
        subscription = create_recurring_data(options)

        anet_subscription_response = transaction.create(subscription)

        build_active_merchant_subscription_response(anet_subscription_response)
      end

      # Update a recurring payment's details.
      #
      # This transaction updates an existing Automated Recurring Billing (ARB) subscription. Your account must have ARB enabled
      # and the subscription must have already been created previously by calling +recurring()+. The ability to change certain
      # details about a recurring payment is dependent on transaction history and cannot be determined until after calling
      # +update_recurring()+. See the ARB XML Guide for such conditions.
      #
      # ==== Parameters
      #
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:subscription_id</tt> -- A string containing the <tt>:subscription_id</tt> of the recurring payment already in place
      #   for a given credit card. (REQUIRED)
      def update_recurring(options={})
        requires!(options, :subscription_id)
        transaction = get_recurring_transaction
        subscription = update_recurring_data(options)

        anet_subscription_response = transaction.update(subscription)

        build_active_merchant_subscription_response(anet_subscription_response)
      end

      # Cancel a recurring payment.
      #
      # This transaction cancels an existing Automated Recurring Billing (ARB) subscription. Your account must have ARB enabled
      # and the subscription must have already been created previously by calling recurring()
      #
      # ==== Parameters
      #
      # * <tt>subscription_id</tt> -- A string containing the +subscription_id+ of the recurring payment already in place
      #   for a given credit card. (REQUIRED)
      def cancel_recurring(subscription_id)
        transaction = get_recurring_transaction
        anet_subscription_response = transaction.cancel(subscription_id)

        build_active_merchant_subscription_response(anet_subscription_response)
      end

      # Get Subscription Status of a recurring payment.
      #
      # This transaction gets the status of an existing Automated Recurring Billing (ARB) subscription. Your account must have ARB enabled.
      #
      # ==== Parameters
      #
      # * <tt>subscription_id</tt> -- A string containing the +subscription_id+ of the recurring payment already in place
      #   for a given credit card. (REQUIRED)
      def status_recurring(subscription_id)
        transaction = get_recurring_transaction
        anet_subscription_response = transaction.get_status(subscription_id)

        build_active_merchant_subscription_response(anet_subscription_response)
      end
    end
  end
end
