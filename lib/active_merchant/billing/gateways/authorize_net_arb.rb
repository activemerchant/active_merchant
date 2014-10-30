module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
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
    class AuthorizeNetArbGateway < Gateway
      API_VERSION = '3.1'

      self.test_url = 'https://apitest.authorize.net/xml/v1/request.api'
      self.live_url = 'https://api.authorize.net/xml/v1/request.api'

      self.default_currency = 'USD'

      self.supported_countries = ['US', 'CA', 'GB']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'Authorize.Net'

      AUTHORIZE_NET_ARB_NAMESPACE = 'AnetApi/xml/v1/schema/AnetApiSchema.xsd'

      RECURRING_ACTIONS = {
        :create => 'ARBCreateSubscription',
        :update => 'ARBUpdateSubscription',
        :cancel => 'ARBCancelSubscription',
        :status => 'ARBGetSubscriptionStatus'
      }

      # Creates a new AuthorizeNetArbGateway
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
        ActiveMerchant.deprecated "ARB functionality in ActiveMerchant is deprecated and will be removed in a future version. Please contact the ActiveMerchant maintainers if you have an interest in taking ownership of a separate gem that continues support for it."
        requires!(options, :login, :password)
        super
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

      # Builds recurring billing request
      def build_recurring_request(action, options = {})
        unless RECURRING_ACTIONS.include?(action)
          raise StandardError, "Invalid Automated Recurring Billing Action: #{action}"
        end

        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.tag!("#{RECURRING_ACTIONS[action]}Request", :xmlns => AUTHORIZE_NET_ARB_NAMESPACE) do
          add_merchant_authentication(xml)
          # Merchant-assigned reference ID for the request
          xml.tag!('refId', options[:ref_id]) if options[:ref_id]
          send("build_#{action}_subscription_request", xml, options)
        end
      end

      # Contains the merchant’s payment gateway account authentication information
      def add_merchant_authentication(xml)
        xml.tag!('merchantAuthentication') do
          xml.tag!('name', @options[:login])
          xml.tag!('transactionKey', @options[:password])
        end
      end

      # Builds body for ARBCreateSubscriptionRequest
      def build_create_subscription_request(xml, options)
        # Subscription
        add_subscription(xml, options)

        xml.target!
      end

      # Builds body for ARBUpdateSubscriptionRequest
      def build_update_subscription_request(xml, options)
        xml.tag!('subscriptionId', options[:subscription_id])
        # Adds Subscription
        add_subscription(xml, options)

        xml.target!
      end

      # Builds body for ARBCancelSubscriptionRequest
      def build_cancel_subscription_request(xml, options)
        xml.tag!('subscriptionId', options[:subscription_id])

        xml.target!
      end

      # Builds body for ARBGetSubscriptionStatusRequest
      def build_status_subscription_request(xml, options)
        xml.tag!('subscriptionId', options[:subscription_id])

        xml.target!
      end

      # Adds subscription information
      def add_subscription(xml, options)
        xml.tag!('subscription') do
          # Merchant-assigned name for the subscription (optional)
          xml.tag!('name', options[:subscription_name]) if options[:subscription_name]
          # Contains information about the payment schedule
          add_payment_schedule(xml, options)
          # The amount to be billed to the customer
          # for each payment in the subscription
          xml.tag!('amount', amount(options[:amount])) if options[:amount]
          if trial = options[:trial]
            # The amount to be charged for each payment during a trial period (conditional)
            xml.tag!('trialAmount', amount(trial[:amount])) if trial[:amount]
          end
          # Contains either the customer’s credit card
          # or bank account payment information
          add_payment(xml, options)
          # Contains order information (optional)
          add_order(xml, options)
          # Contains information about the customer
          add_customer(xml, options)
          # Contains the customer's billing address information
          add_address(xml, 'billTo', options[:billing_address])
          # Contains the customer's shipping address information (optional)
          add_address(xml, 'shipTo', options[:shipping_address])
        end
      end

      # Adds information about the interval of time between payments
      def add_interval(xml, options)
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
      def add_duration(xml, options)
        duration = options[:duration]
        return unless duration
        # The date the subscription begins
        # (also the date the initial billing occurs)
        xml.tag!('startDate', duration[:start_date]) if duration[:start_date]
        # Number of billing occurrences or payments for the subscription
        xml.tag!('totalOccurrences', duration[:occurrences]) if duration[:occurrences]
      end

      def add_payment_schedule(xml, options)
        return unless options[:interval] || options[:duration]
        xml.tag!('paymentSchedule') do
          # Contains information about the interval of time between payments
          add_interval(xml, options)
          add_duration(xml, options)
          if trial = options[:trial]
            # Number of billing occurrences or payments in the trial period (optional)
            xml.tag!('trialOccurrences', trial[:occurrences]) if trial[:occurrences]
          end
        end
      end

      # Adds customer's credit card or bank account payment information
      def add_payment(xml, options)
        return unless options[:credit_card] || options[:bank_account]
        xml.tag!('payment') do
          # Contains the customer’s credit card information
          add_credit_card(xml, options)
          # Contains the customer’s bank account information
          add_bank_account(xml, options)
        end
      end

      # Adds customer’s credit card information
      # Note: This element should only be included
      # when the payment method is credit card.
      def add_credit_card(xml, options)
        credit_card = options[:credit_card]
        return unless credit_card
        xml.tag!('creditCard') do
          # The credit card number used for payment of the subscription
          xml.tag!('cardNumber', credit_card.number)
          # The expiration date of the credit card used for the subscription
          xml.tag!('expirationDate', expdate(credit_card))
        end
      end

      # Adds customer’s bank account information
      # Note: This element should only be included
      # when the payment method is bank account.
      def add_bank_account(xml, options)
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
      def add_order(xml, options)
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
      def add_customer(xml, options)
        customer = options[:customer]
        return unless customer
        xml.tag!('customer') do
          xml.tag!('type', customer[:type]) if customer[:type]
          xml.tag!('id', customer[:id]) if customer[:id]
          xml.tag!('email', customer[:email]) if customer[:email]
          xml.tag!('phoneNumber', customer[:phone_number]) if customer[:phone_number]
          xml.tag!('faxNumber', customer[:fax_number]) if customer[:fax_number]
          add_drivers_license(xml, options)
          xml.tag!('taxId', customer[:tax_id]) if customer[:tax_id]
        end
      end

      # Adds the customer's driver's license information (conditional)
      def add_drivers_license(xml, options)
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
      def add_address(xml, container_name, address)
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

      def expdate(credit_card)
        sprintf('%04d-%02d', credit_card.year, credit_card.month)
      end

      def recurring_commit(action, request)
        url = test? ? test_url : live_url
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
          node.elements.each{|e| recurring_parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end
    end
  end
end
