module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on the Metrics Global Payment Gateway, visit the {Metrics Global website}[www.metricsglobal.com].
    # Further documentation on AVS and CVV response codes are available under the support section of the Metrics Global
    # control panel.
    #
    # === Metrics Global Payment Gateway Authentication
    #
    # The login and password for the gateway are the same as the username and password used to log in to the Metrics Global
    # control panel. Contact Metrics Global support to receive credentials for the control panel.
    #
    # === Demo Account
    #
    # There is a public demo account available with the following credentials:
    #
    # Login: demo
    # Password: password
    class MetricsGlobalGateway < Gateway
      API_VERSION = '3.1'

      class_attribute :test_url, :live_url

      self.test_url = "https://secure.metricsglobalgateway.com/gateway/transact.dll?testing=true"
      self.live_url = "https://secure.metricsglobalgateway.com/gateway/transact.dll"

      class_attribute :duplicate_window

      APPROVED, DECLINED, ERROR, FRAUD_REVIEW = 1, 2, 3, 4

      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT = 0, 2, 3
      AVS_RESULT_CODE, TRANSACTION_ID, CARD_CODE_RESPONSE_CODE  = 5, 6, 38

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url = 'http://www.metricsglobal.com'
      self.display_name = 'Metrics Global'

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )
      AVS_REASON_CODES = %w(27 45)

      # Creates a new MetricsGlobalGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The username required to access the Metrics Global control panel. (REQUIRED)
      # * <tt>:password</tt> -- The password required to access the Metrics Global control panel. (REQUIRED)
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test server. 
      #   Otherwise, perform transactions against the production server.
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      # Performs an authorization, which reserves the funds on the customer's credit card, but does not
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
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
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
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

        # Only activate the test_request when the :test option is passed in
        parameters[:test_request] = @options[:test] ? 'TRUE' : 'FALSE'

        url = test? ? self.test_url : self.live_url
        data = ssl_post url, post_data(action, parameters)

        response = parse(data)

        message = message_from(response)

        # Return the response. The authorization can be taken out of the transaction_id
        # Test Mode on/off is something we have to parse from the response text.
        # It usually looks something like this
        #
        #   (TESTMODE) Successful Sale
        test_mode = test? || message =~ /TESTMODE/

        Response.new(success?(response), message, response, 
          :test => test_mode, 
          :authorization => response[:transaction_id],
          :fraud_review => fraud_review?(response),
          :avs_result => { :code => response[:avs_result_code] },
          :cvv_result => response[:card_code]
        )
      end

      def success?(response)
        response[:response_code] == APPROVED
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
          :card_code => fields[CARD_CODE_RESPONSE_CODE]
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

      def add_invoice(post, options)
        post[:invoice_num] = options[:order_id]
        post[:description] = options[:description]
      end

      def add_creditcard(post, creditcard)
        post[:card_num]   = creditcard.number
        post[:card_code]  = creditcard.verification_value if creditcard.verification_value?
        post[:exp_date]   = expdate(creditcard)
        post[:first_name] = creditcard.first_name
        post[:last_name]  = creditcard.last_name
      end

      def add_customer_data(post, options)
        if options.has_key? :email
          post[:email] = options[:email]
          post[:email_customer] = false
        end

        if options.has_key? :customer
          post[:cust_id] = options[:customer]
        end

        if options.has_key? :ip
          post[:customer_ip] = options[:ip]
        end
      end
      
      # x_duplicate_window won't be sent by default, because sending it changes the response.
      # "If this field is present in the request with or without a value, an enhanced duplicate transaction response will be sent."
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

      # Make a ruby type out of the response string
      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
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
