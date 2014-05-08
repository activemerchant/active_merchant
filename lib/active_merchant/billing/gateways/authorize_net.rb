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
    class AuthorizeNetGateway < Gateway
      API_VERSION = '3.1'

      self.test_url = "https://test.authorize.net/gateway/transact.dll"
      self.live_url = "https://secure.authorize.net/gateway/transact.dll"

      class_attribute :duplicate_window

      APPROVED, DECLINED, ERROR, FRAUD_REVIEW = 1, 2, 3, 4

      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT, AUTHORIZATION_CODE = 0, 2, 3, 4
      AVS_RESULT_CODE, TRANSACTION_ID, CARD_CODE_RESPONSE_CODE, CARDHOLDER_AUTH_CODE  = 5, 6, 38, 39

      self.default_currency = 'USD'

      self.supported_countries = %w(AD AT AU BE BG CA CH CY CZ DE DK ES FI FR GB GB GI GR HU IE IT LI LU MC MT NL NO PL PT RO SE SI SK SM TR US VA)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'Authorize.Net'

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )
      AVS_REASON_CODES = %w(27 45)
      TRANSACTION_ALREADY_ACTIONED = %w(310 311)

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
        post = {}
        add_currency_code(post, money, options)
        add_invoice(post, options)
        add_payment_source(post, paysource, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_duplicate_window(post)

        commit('AUTH_ONLY', money, post)
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>paysource</tt> -- The CreditCard or Check details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, paysource, options = {})
        post = {}
        add_currency_code(post, money, options)
        add_invoice(post, options)
        add_payment_source(post, paysource, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_duplicate_window(post)

        commit('AUTH_CAPTURE', money, post)
      end

      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      def capture(money, authorization, options = {})
        post = {:trans_id => authorization}
        add_customer_data(post, options)
        add_invoice(post, options)
        commit('PRIOR_AUTH_CAPTURE', money, post)
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
      def void(authorization, options = {})
        post = {:trans_id => authorization}
        add_duplicate_window(post)
        commit('VOID', nil, post)
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
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:card_number</tt> -- The credit card number the refund is being issued to. (REQUIRED)
      #   You can either pass the last four digits of the card number or the full card number.
      # * <tt>:first_name</tt> -- The first name of the account being refunded.
      # * <tt>:last_name</tt> -- The last name of the account being refunded.
      # * <tt>:zip</tt> -- The postal code of the account being refunded.
      def refund(money, identification, options = {})
        requires!(options, :card_number)

        post = { :trans_id => identification,
                 :card_num => options[:card_number]
               }

        post[:first_name] = options[:first_name] if options[:first_name]
        post[:last_name] = options[:last_name] if options[:last_name]
        post[:zip] = options[:zip] if options[:zip]

        add_invoice(post, options)
        add_duplicate_window(post)

        commit('CREDIT', money, post)
      end

      def credit(money, identification, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      private

      def commit(action, money, parameters)
        parameters[:amount] = amount(money) unless action == 'VOID'

        url = test? ? self.test_url : self.live_url
        data = ssl_post url, post_data(action, parameters)

        response          = parse(data)
        response[:action] = action

        message = message_from(response)

        Response.new(success?(response), message, response,
          :test => test?,
          :authorization => response[:transaction_id],
          :fraud_review => fraud_review?(response),
          :avs_result => { :code => response[:avs_result_code] },
          :cvv_result => response[:card_code]
        )
      end

      def success?(response)
        response[:response_code] == APPROVED && TRANSACTION_ALREADY_ACTIONED.exclude?(response[:response_reason_code])
      end

      def fraud_review?(response)
        response[:response_code] == FRAUD_REVIEW
      end

      def parse(body)
        fields = split(body)

        results = {
          :response_code => fields[RESPONSE_CODE].to_i,
          :response_reason_code => fields[RESPONSE_REASON_CODE],
          :response_reason_text => fields[RESPONSE_REASON_TEXT],
          :avs_result_code => fields[AVS_RESULT_CODE],
          :transaction_id => fields[TRANSACTION_ID],
          :card_code => fields[CARD_CODE_RESPONSE_CODE],
          :authorization_code => fields[AUTHORIZATION_CODE],
          :cardholder_authentication_code => fields[CARDHOLDER_AUTH_CODE]
        }
        results
      end

      def post_data(action, parameters = {})
        post = {}

        post[:version]        = API_VERSION
        post[:login]          = @options[:login]
        post[:tran_key]       = @options[:password]
        post[:relay_response] = "FALSE"
        post[:type]           = action
        post[:delim_data]     = "TRUE"
        post[:delim_char]     = ","
        post[:encap_char]     = "$"
        post[:solution_ID]    = application_id if application_id.present? && application_id != "ActiveMerchant"

        request = post.merge(parameters).collect { |key, value| "x_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def add_currency_code(post, money, options)
        post[:currency_code] = options[:currency] || currency(money)
      end

      def add_invoice(post, options)
        post[:invoice_num] = options[:order_id]
        post[:description] = options[:description]
      end

      def add_creditcard(post, creditcard, options={})
        post[:card_num]   = creditcard.number
        post[:card_code]  = creditcard.verification_value if creditcard.verification_value?
        post[:exp_date]   = expdate(creditcard)
        post[:first_name] = creditcard.first_name
        post[:last_name]  = creditcard.last_name
      end

      def add_payment_source(params, source, options={})
        if card_brand(source) == "check"
          add_check(params, source, options)
        else
          add_creditcard(params, source, options)
        end
      end

      def add_check(post, check, options)
        post[:method] = "ECHECK"
        post[:bank_name] = check.bank_name
        post[:bank_aba_code] = check.routing_number
        post[:bank_acct_num] = check.account_number
        post[:bank_acct_type] = check.account_type
        post[:echeck_type] = "WEB"
        post[:bank_acct_name] = check.name
        post[:bank_check_number] = check.number if check.number.present?
        post[:recurring_billing] = (options[:recurring] ? "TRUE" : "FALSE")
      end

      def add_customer_data(post, options)
        if options.has_key? :email
          post[:email] = options[:email]
          post[:email_customer] = false
        end

        if options.has_key? :customer
          post[:cust_id] = options[:customer] if Float(options[:customer]) rescue nil
        end

        if options.has_key? :ip
          post[:customer_ip] = options[:ip]
        end

        if options.has_key? :cardholder_authentication_value
          post[:cardholder_authentication_value] = options[:cardholder_authentication_value]
        end

        if options.has_key? :authentication_indicator
          post[:authentication_indicator] = options[:authentication_indicator]
        end

      end

      # x_duplicate_window won't be sent by default, because sending it changes the response.
      # "If this field is present in the request with or without a value, an enhanced duplicate transaction response will be sent."
      # (as of 2008-12-30) http://www.authorize.net/support/AIM_guide_SCC.pdf
      def add_duplicate_window(post)
        unless duplicate_window.nil?
          post[:duplicate_window] = duplicate_window
        end
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:address] = address[:address1].to_s
          post[:company] = address[:company].to_s
          post[:phone]   = address[:phone].to_s
          post[:zip]     = address[:zip].to_s
          post[:city]    = address[:city].to_s
          post[:country] = address[:country].to_s
          post[:state]   = address[:state].blank?  ? 'n/a' : address[:state]
        end

        if address = options[:shipping_address]
          post[:ship_to_first_name] = address[:first_name].to_s
          post[:ship_to_last_name] = address[:last_name].to_s
          post[:ship_to_address] = address[:address1].to_s
          post[:ship_to_company] = address[:company].to_s
          post[:ship_to_phone]   = address[:phone].to_s
          post[:ship_to_zip]     = address[:zip].to_s
          post[:ship_to_city]    = address[:city].to_s
          post[:ship_to_country] = address[:country].to_s
          post[:ship_to_state]   = address[:state].blank?  ? 'n/a' : address[:state]
        end
      end

      def message_from(results)
        if results[:response_code] == DECLINED
          return CVVResult.messages[ results[:card_code] ] if CARD_CODE_ERRORS.include?(results[:card_code])
          if AVS_REASON_CODES.include?(results[:response_reason_code]) && AVS_ERRORS.include?(results[:avs_result_code])
            return AVSResult.messages[ results[:avs_result_code] ]
          end
        end

        (results[:response_reason_text] ? results[:response_reason_text].chomp('.') : '')
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def split(response)
        response[1..-2].split(/\$,\$/)
      end
    end
  end
end
