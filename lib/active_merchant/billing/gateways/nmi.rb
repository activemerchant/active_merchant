module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NmiGateway < Gateway
      API_VERSION = '3.1'

      self.test_url = 'https://secure.networkmerchants.com/gateway/transact.dll'
      self.live_url = 'https://secure.networkmerchants.com/gateway/transact.dll'

      class_attribute :duplicate_window

      APPROVED, DECLINED, ERROR, FRAUD_REVIEW = 1, 2, 3, 4

      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT, AUTHORIZATION_CODE = 0, 2, 3, 4
      AVS_RESULT_CODE, TRANSACTION_ID, CARD_CODE_RESPONSE_CODE, CARDHOLDER_AUTH_CODE = 5, 6, 38, 39

      self.default_currency = 'USD'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://nmi.com/'
      self.display_name = 'NMI'

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )
      AVS_REASON_CODES = %w(27 45)
      TRANSACTION_ALREADY_ACTIONED = %w(310 311)

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

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

      def capture(money, authorization, options = {})
        post = {:trans_id => authorization}
        add_customer_data(post, options)
        add_invoice(post, options)
        commit('PRIOR_AUTH_CAPTURE', money, post)
      end

      def void(authorization, options = {})
        post = {:trans_id => authorization}
        add_duplicate_window(post)
        commit('VOID', nil, post)
      end

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
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def commit(action, money, parameters)
        parameters[:amount] = amount(money) unless action == 'VOID'

        url = test? ? self.test_url : self.live_url
        data = ssl_post(url, post_data(action, parameters))

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

        post[:recurring_billing] = "TRUE" if options[:recurring]
      end

      def add_payment_source(params, source, options={})
        add_creditcard(params, source, options)
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

      def split(response)
        response[1..-2].split(/\$,\$/)
      end
    end
  end
end

