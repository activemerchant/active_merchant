module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    require 'authorizenet'
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
      API_VERSION = '4.0'

      class_attribute :arb_test_url, :arb_live_url

      self.test_url = "https://test.authorize.net/gateway/transact.dll"
      self.live_url = "https://secure.authorize.net/gateway/transact.dll"

      self.arb_test_url = 'https://apitest.authorize.net/xml/v1/request.api'
      self.arb_live_url = 'https://api.authorize.net/xml/v1/request.api'

      class_attribute :duplicate_window, :partial_test_mode

      self.partial_test_mode = false;

      APPROVED, DECLINED, ERROR, FRAUD_REVIEW = 1, 2, 3, 4

      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT, AUTHORIZATION_CODE = 0, 2, 3, 4
      AVS_RESULT_CODE, TRANSACTION_ID, CARD_CODE_RESPONSE_CODE, CARDHOLDER_AUTH_CODE = 5, 6, 38, 39

      self.default_currency = 'USD'

      self.supported_countries = ['US', 'CA', 'GB']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'Authorize.Net'

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )
      AVS_REASON_CODES = %w(27 45)
      TRANSACTION_ALREADY_ACTIONED = %w(310 311)

      AUTHORIZE_NET_ARB_NAMESPACE = 'AnetApi/xml/v1/schema/AnetApiSchema.xsd'

      RECURRING_ACTIONS = {
          :create => 'ARBCreateSubscription',
          :update => 'ARBUpdateSubscription',
          :cancel => 'ARBCancelSubscription',
          :status => 'ARBGetSubscriptionStatus'
      }

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
      # * <tt>credit_card</tt> -- The ActiveMerchant::Billing::CreditCard used in the original transaction against which the refund is being issued.
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

        request = build_recurring_request(:create, options)
        recurring_commit(:create, request)
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
        request = build_recurring_request(:update, options)
        recurring_commit(:update, request)
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
        request = build_recurring_request(:cancel, :subscription_id => subscription_id)
        recurring_commit(:cancel, request)
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
        request = build_recurring_request(:status, :subscription_id => subscription_id)
        recurring_commit(:status, request)
      end

      private

      def get_transaction
        gateway = test? ? :sandbox : :live
        test_mode = test? ? partial_test_mode : true
        transaction = AuthorizeNet::AIM::Transaction.new(@options[:login], @options[:password], :gateway => gateway, :test => test_mode)
      end

      def build_active_merchant_response(anet_response)
        Response.new(anet_response.success?, anet_response.fields[:response_reason_text], anet_response.fields,
                     :test => test?,
                     :authorization => anet_response.authorization_code
        #:avs_result => response.avs_response
        #{:cvv_result => response.card_code}
        )
      end

      def success?(response)
        response[:response_code] == APPROVED && TRANSACTION_ALREADY_ACTIONED.exclude?(response[:response_reason_code])
      end

      def fraud_review?(response)
        response[:response_code] == FRAUD_REVIEW
      end

      def get_action_type(action)
        type = ACTION_TYPES[action]
      end

      def add_currency_code(transaction, money, options)
        # post[:currency_code] = options[:currency] || currency(money)
      end

      def add_invoice(transaction, options)
        transaction.fields[:invoice_num] = options[:order_id]
        transaction.fields[:description] = options[:description]
      end

      def add_creditcard(creditcard, options={})
        options[:card_type] = creditcard.brand
        options[:card_code] = creditcard.verification_value if creditcard.verification_value?
        #options[:first_name] = creditcard.first_name
        #options[:last_name] = creditcard.last_name
        @payment_source = AuthorizeNet::CreditCard.new(creditcard.number, expdate(creditcard), options)
      end

      def get_payment_source(source, options={})
        if card_brand(source) == "check"
          add_check(source, options)
        else
          add_creditcard(source, options)
        end
      end

      def add_check(check, options={})
        options[:echeck_type] = "WEB"
        options[:check_number] = check.number if check.number.present?
        options[:recurring] = (options[:recurring] ? "TRUE" : "FALSE")
        @payment_source = AuthorizeNet::ECheck.new(check.routing_number, check.account_number, check.bank_name, check.name, options)
      end

      def add_customer_data(transaction, options)
        if options.has_key? :email
          transaction.fields[:email] = options[:email]
          transaction.fields[:email_customer] = false
        end

        if options.has_key? :customer
          transaction.fields[:cust_id] = options[:customer] if Float(options[:customer]) rescue nil
        end

        if options.has_key? :ip
          transaction.fields[:customer_ip] = options[:ip]
        end

        if options.has_key? :cardholder_authentication_value
          transaction.fields[:cardholder_authentication_value] = options[:cardholder_authentication_value]
        end

        if options.has_key? :authentication_indicator
          transaction.fields[:authentication_indicator] = options[:authentication_indicator]
        end

      end

      # x_duplicate_window won't be sent by default, because sending it changes the response.
      # "If this field is present in the request with or without a value, an enhanced duplicate transaction response will be sent."
      # (as of 2008-12-30) http://www.authorize.net/support/AIM_guide_SCC.pdf
      def add_duplicate_window(transaction)
        unless duplicate_window.nil?
          transaction.fields[:duplicate_window] = duplicate_window
        end
      end

      def add_address(transaction, options)
        if address_hash = options[:billing_address] || options[:address]
          address_to_add = AuthorizeNet::Address.new

          address_to_add.street_address = address_hash[:address1].to_s
          address_to_add.company = address_hash[:company].to_s
          address_to_add.phone = address_hash[:phone].to_s
          address_to_add.zip = address_hash[:zip].to_s
          address_to_add.city = address_hash[:city].to_s
          address_to_add.country = address_hash[:country].to_s
          address_to_add.state = address_hash[:state].blank? ? 'n/a' : address_hash[:state]

          transaction.set_address(address_to_add)
        end

        if address_hash = options[:shipping_address]
          address_to_add = AuthorizeNet::ShippingAddress.new

          address_to_add.first_name = address_hash[:first_name].to_s
          address_to_add.last_name = address_hash[:last_name].to_s

          address_to_add.street_address = address_hash[:address1].to_s
          address_to_add.company = address_hash[:company].to_s
          address_to_add.phone = address_hash[:phone].to_s
          address_to_add.zip = address_hash[:zip].to_s
          address_to_add.city = address_hash[:city].to_s
          address_to_add.country = address_hash[:country].to_s
          address_to_add.state = address_hash[:state].blank? ? 'n/a' : address_hash[:state]

          transaction.set_shipping_address(address_to_add)
        end

      end

      # Make a ruby type out of the response string
      def normalize(field)
        case field
          when "true" then
            true
          when "false" then
            false
          when "" then
            nil
          when "null" then
            nil
          else
            field
        end
      end

      def expdate(creditcard)
        year = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def split(response)
        response[1..-2].split(/\$,\$/)
      end

      # ARB

      # Builds recurring billing request
      def build_recurring_request(action, options = {})
        unless RECURRING_ACTIONS.include?(action)
          raise StandardError, "Invalid Automated Recurring Billing Action: #{action}"
        end

        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.tag!("#{RECURRING_ACTIONS[action]}Request", :xmlns => AUTHORIZE_NET_ARB_NAMESPACE) do
          add_arb_merchant_authentication(xml)
          # Merchant-assigned reference ID for the request
          xml.tag!('refId', options[:ref_id]) if options[:ref_id]
          send("build_arb_#{action}_subscription_request", xml, options)
        end
      end

      # Contains the merchant’s payment gateway account authentication information
      def add_arb_merchant_authentication(xml)
        xml.tag!('merchantAuthentication') do
          xml.tag!('name', @options[:login])
          xml.tag!('transactionKey', @options[:password])
        end
      end

      # Builds body for ARBCreateSubscriptionRequest
      def build_arb_create_subscription_request(xml, options)
        # Subscription
        add_arb_subscription(xml, options)

        xml.target!
      end

      # Builds body for ARBUpdateSubscriptionRequest
      def build_arb_update_subscription_request(xml, options)
        xml.tag!('subscriptionId', options[:subscription_id])
        # Adds Subscription
        add_arb_subscription(xml, options)

        xml.target!
      end

      # Builds body for ARBCancelSubscriptionRequest
      def build_arb_cancel_subscription_request(xml, options)
        xml.tag!('subscriptionId', options[:subscription_id])

        xml.target!
      end

      # Builds body for ARBGetSubscriptionStatusRequest
      def build_arb_status_subscription_request(xml, options)
        xml.tag!('subscriptionId', options[:subscription_id])

        xml.target!
      end

      # Adds subscription information
      def add_arb_subscription(xml, options)
        xml.tag!('subscription') do
          # Merchant-assigned name for the subscription (optional)
          xml.tag!('name', options[:subscription_name]) if options[:subscription_name]
          # Contains information about the payment schedule
          add_arb_payment_schedule(xml, options)
          # The amount to be billed to the customer
          # for each payment in the subscription
          xml.tag!('amount', amount(options[:amount])) if options[:amount]
          if trial = options[:trial]
            # The amount to be charged for each payment during a trial period (conditional)
            xml.tag!('trialAmount', amount(trial[:amount])) if trial[:amount]
          end
          # Contains either the customer’s credit card
          # or bank account payment information
          add_arb_payment(xml, options)
          # Contains order information (optional)
          add_arb_order(xml, options)
          # Contains information about the customer
          add_arb_customer(xml, options)
          # Contains the customer's billing address information
          add_arb_address(xml, 'billTo', options[:billing_address])
          # Contains the customer's shipping address information (optional)
          add_arb_address(xml, 'shipTo', options[:shipping_address])
        end
      end

      # Adds information about the interval of time between payments
      def add_arb_interval(xml, options)
        interval = options[:interval]
        return unless interval
        xml.tag!('interval') do
          # The measurement of time, in association with the Interval Unit,
          # that is used to define the frequency of the billing occurrences
          xml.tag!('length', interval[:length])
          # The unit of time, in association with the Interval Length,
          # between each billing occurrence
          xml.tag!('unit', interval[:unit].to_s)
        end
      end

      # Adds information about the subscription duration
      def add_arb_duration(xml, options)
        duration = options[:duration]
        return unless duration
        # The date the subscription begins
        # (also the date the initial billing occurs)
        xml.tag!('startDate', duration[:start_date]) if duration[:start_date]
        # Number of billing occurrences or payments for the subscription
        xml.tag!('totalOccurrences', duration[:occurrences]) if duration[:occurrences]
      end

      def add_arb_payment_schedule(xml, options)
        return unless options[:interval] || options[:duration]
        xml.tag!('paymentSchedule') do
          # Contains information about the interval of time between payments
          add_arb_interval(xml, options)
          add_arb_duration(xml, options)
          if trial = options[:trial]
            # Number of billing occurrences or payments in the trial period (optional)
            xml.tag!('trialOccurrences', trial[:occurrences]) if trial[:occurrences]
          end
        end
      end

      # Adds customer's credit card or bank account payment information
      def add_arb_payment(xml, options)
        return unless options[:credit_card] || options[:bank_account]
        xml.tag!('payment') do
          # Contains the customer’s credit card information
          add_arb_credit_card(xml, options)
          # Contains the customer’s bank account information
          add_arb_bank_account(xml, options)
        end
      end

      # Adds customer’s credit card information
      # Note: This element should only be included
      # when the payment method is credit card.
      def add_arb_credit_card(xml, options)
        credit_card = options[:credit_card]
        return unless credit_card
        xml.tag!('creditCard') do
          # The credit card number used for payment of the subscription
          xml.tag!('cardNumber', credit_card.number)
          # The expiration date of the credit card used for the subscription
          xml.tag!('expirationDate', arb_expdate(credit_card))
        end
      end

      # Adds customer’s bank account information
      # Note: This element should only be included
      # when the payment method is bank account.
      def add_arb_bank_account(xml, options)
        bank_account = options[:bank_account]
        return unless bank_account
        xml.tag!('bankAccount') do
          # The type of bank account used for payment of the subscription
          xml.tag!('accountType', bank_account[:account_type])
          # The routing number of the customer’s bank
          xml.tag!('routingNumber', bank_account[:routing_number])
          # The bank account number used for payment of the subscription
          xml.tag!('accountNumber', bank_account[:account_number])
          # The full name of the individual associated
          # with the bank account number
          xml.tag!('nameOfAccount', bank_account[:name_of_account])
          # The full name of the individual associated
          # with the bank account number (optional)
          xml.tag!('bankName', bank_account[:bank_name]) if bank_account[:bank_name]
          # The type of electronic check transaction used for the subscription
          xml.tag!('echeckType', bank_account[:echeck_type])
        end
      end

      # Adds order information (optional)
      def add_arb_order(xml, options)
        order = options[:order]
        return unless order
        xml.tag!('order') do
          # Merchant-assigned invoice number for the subscription (optional)
          xml.tag!('invoiceNumber', order[:invoice_number])
          # Description of the subscription (optional)
          xml.tag!('description', order[:description])
        end
      end

      # Adds information about the customer
      def add_arb_customer(xml, options)
        customer = options[:customer]
        return unless customer
        xml.tag!('customer') do
          xml.tag!('type', customer[:type]) if customer[:type]
          xml.tag!('id', customer[:id]) if customer[:id]
          xml.tag!('email', customer[:email]) if customer[:email]
          xml.tag!('phoneNumber', customer[:phone_number]) if customer[:phone_number]
          xml.tag!('faxNumber', customer[:fax_number]) if customer[:fax_number]
          add_arb_drivers_license(xml, options)
          xml.tag!('taxId', customer[:tax_id]) if customer[:tax_id]
        end
      end

      # Adds the customer's driver's license information (conditional)
      def add_arb_drivers_license(xml, options)
        return unless customer = options[:customer]
        return unless drivers_license = customer[:drivers_license]
        xml.tag!('driversLicense') do
          # The customer's driver's license number
          xml.tag!('number', drivers_license[:number])
          # The customer's driver's license state
          xml.tag!('state', drivers_license[:state])
          # The customer's driver's license date of birth
          xml.tag!('dateOfBirth', drivers_license[:date_of_birth])
        end
      end

      # Adds address information
      def add_arb_address(xml, container_name, address)
        return if address.blank?
        xml.tag!(container_name) do
          xml.tag!('firstName', address[:first_name])
          xml.tag!('lastName', address[:last_name])
          xml.tag!('company', address[:company])
          xml.tag!('address', address[:address1])
          xml.tag!('city', address[:city])
          xml.tag!('state', address[:state])
          xml.tag!('zip', address[:zip])
          xml.tag!('country', address[:country])
        end
      end

      def arb_expdate(credit_card)
        sprintf('%04d-%02d', credit_card.year, credit_card.month)
      end

      def recurring_commit(action, request)
        url = test? ? arb_test_url : arb_live_url
        xml = ssl_post(url, request, "Content-Type" => "text/xml")

        response = recurring_parse(action, xml)

        message = response[:message] || response[:text]
        test_mode = test? || message =~ /Test Mode/
        success = response[:result_code] == 'Ok'

        Response.new(success, message, response,
                     :test => test_mode,
                     :authorization => response[:subscription_id]
        )
      end

      def recurring_parse(action, xml)
        response = {}
        xml = REXML::Document.new(xml)
        root = REXML::XPath.first(xml, "//#{RECURRING_ACTIONS[action]}Response") ||
            REXML::XPath.first(xml, "//ErrorResponse")
        if root
          root.elements.to_a.each do |node|
            recurring_parse_element(response, node)
          end
        end

        response
      end

      def recurring_parse_element(response, node)
        if node.has_elements?
          node.elements.each { |e| recurring_parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end
    end
  end
end
