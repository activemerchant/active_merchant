module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayfortGateway < Gateway #:nodoc:
      self.test_url = 'https://sbcheckout.payfort.com/FortAPI'
      self.live_url = 'https://checkout.payfort.com/FortAPI'
      self.supported_countries = %w(EG AE)
      self.default_currency = 'AED'
      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'http://www.payfort.com/'
      self.display_name = 'PayFort'

      ERROR_CODES = {
        '00' => 'Invalid Request',
        '01' => 'Order Stored',
        '02' => 'Authorization Success',
        '03' => 'Authorization Failed',
        '04' => 'Capture Success',
        '05' => 'Capture failed',
        '06' => 'Refund Success',
        '07' => 'Refund Failed',
        '08' => 'Authorization Voided Successfully',
        '09' => 'Authorization Void Failed',
        '10' => 'Incomplete',
        '11' => 'Check status Failed',
        '12' => 'Check status success',
        '13' => 'Purchase Failure',
        '14' => 'Purchase Success',
        '15' => 'Uncertain Transaction',
        '17' => 'Tokenization failed',
        '18' => 'Tokenization success',
        '19' => 'Transaction pending',
        '20' => 'On hold',
        '21' => 'SDK token creation failure',
        '22' => 'SDK token creation success'
      }.freeze

      SUCCESS_CODES = %w(01 02 04 06 08 12 14 18 22).freeze
      FAILURE_CODES = %w(00 03 05 07 09 11 13 21).freeze

      MESSAGE_CODES = {
        '000' => 'Success',
        '001' => 'Missing parameter',
        '002' => 'Invalid parameter format',
        '003' => 'Payment option is not available for this merchant\’s account',
        '004' => 'Invalid command',
        '005' => 'Invalid amount',
        '006' => 'Technical problem',
        '007' => 'Duplicate order number',
        '008' => 'Signature mismatch',
        '009' => 'Invalid merchant identifier',
        '010' => 'Invalid access code',
        '011' => 'Order not saved',
        '012' => 'Card expired',
        '013' => 'Invalid currency',
        '014' => 'Inactive payment option',
        '015' => 'Inactive merchant account',
        '016' => 'Invalid card number',
        '017' => 'Operation not allowed by the acquirer',
        '018' => 'Operation not allowed by processor',
        '019' => 'Inactive acquirer',
        '020' => 'Processor is inactive',
        '021' => 'Payment option deactivated by acquirer',
        '022' => 'Payment option deactivated by processor',
        '023' => 'Currency not accepted by acquirer',
        '024' => 'Currency not accepted by processor',
        '025' => 'Processor integration settings are missing',
        '026' => 'Acquirer integration settings are missing',
        '027' => 'Invalid extra parameters',
        '028' => 'Missing operations settings.
                  Contact PAYFORT operations support',
        '029' => 'Insufficient funds',
        '030' => 'Authentication failed',
        '031' => 'Invalid issuer',
        '032' => 'Invalid parameter length',
        '033' => 'Parameter value not allowed',
        '034' => 'Operation not allowed',
        '035' => 'Order created successfully',
        '036' => 'Order not found',
        '038' => 'Tokenization service inactive',
        '040' => 'Invalid transaction source as it does not match the
                  Origin URL or the Origin IP',
        '042' => 'Operation amount exceeds the authorized amount',
        '043' => 'Inactive Operation',
        '044' => 'Token name does not exist',
        '045' => 'Merchant does not have the token service
                  and yet "token_name" was sent',
        '046' => 'Channel is not configured for the selected payment option',
        '048' => 'Operation amount exceeds the captured amount',
        '051' => 'Acquirer bank is facing technical difficulties,
                  please try again later',
        '052' => 'Invalid OLP',
        '053' => 'Merchant is not found in OLP Engine DB',
        '054' => 'SADAD is facing technical difficulties,
                  please try again later',
        '055' => 'OLP ID Alias is not valid. Please contact your bank',
        '056' => 'OLP ID Alias does not exist.
                  Please enter a valid OLP ID Alias',
        '057' => 'Transaction amount exceeds the daily transaction limit',
        '058' => 'Transaction amount exceeds the allowed limit per transaction',
        '059' => 'Merchant Name and SADAD Merchant ID do not match',
        '060' => 'The entered OLP password is incorrect.
                  Please provide a valid password',
        '061' => 'Failed to create token',
        '062' => 'Token has been created',
        '063' => 'Token has been updated',
        '064' => '3-D Secure check requested',
        '065' => 'Transaction waiting for payer\'s action',
        '066' => 'Merchant reference already exists',
        '068' => 'SDK service is inactive',
        '070' => 'device_id mismatch',
        '071' => 'Failed to initiate connection',
        '072' => 'Transaction has been cancelled by the consumer',
        '073' => 'Invalid request format',
        '074' => 'Transaction failed',
        '075' => 'Transaction failed',
        '076' => 'Transaction not found in OLP',
        '077' => 'Error transaction code not found',
        '662' => 'Operation not allowed.
                  The specified order is not confirmed yet',
        '666' => 'Transaction declined',
        '773' => 'Transaction closed',
        '777' => 'The transaction has been processed,
                  but failed to receive confirmation',
        '778' => 'Session timed-out',
        '779' => 'Transformation error',
        '780' => 'Transaction number transformation error',
        '781' => 'Message or response code transformation error',
        '783' => 'Installments service inactive',
        '785' => 'Transaction blocked by fraud checker',
        '787' => 'Failed to authenticate the user'
      }.freeze

      # Creates a new PayfortGateway
      #
      # ==== Options
      #
      # * <tt>:identifier</tt> -- Merchant Identifier (REQUIRED)
      # * <tt>:access_code</tt> -- Access Code (REQUIRED)
      # * <tt>:signature_phrase</tt> -- Request Signature Phrase (REQUIRED)
      def initialize(options = {})
        requires!(options, :identifier, :access_code, :signature_phrase)
        super
      end

      def authorize(amount, credit_card_token, _options = {})
        request_params = {}
        request_params[:amount] = amount
        request_params[:command] = 'AUTHORIZATION'
        request_params[:token_name] = credit_card_token
        request_params[:merchant_reference] = options[:id]
        request_params[:currency] = options[:currency] || default_currency
        commit(request_params)
      end

      def capture(amount, credit_card_token, options = {})
        request_params[:amount] = amount
        request_params[:command] = 'CAPTURE'
        request_params[:token_name] = credit_card_token
        request_params[:merchant_reference] = options[:id]
        false
      end

      # Creates a new PayfortGateway
      #
      # ==== Options
      #
      # * <tt>:id</tt> -- Order reference (REQUIRED)
      # * <tt>:email</tt> -- Customer email address (REQUIRED)
      # * <tt>:name</tt> -- Customer name (OPTIONAL)
      # * <tt>:ip</tt> -- Customer IP address (OPTIONAL)
      # * <tt>:currency</tt> -- Currency, defaults to AED (OPTIONAL)
      def purchase(amount, credit_card_token, options = {})
        request_params = {}
        request_params[:amount] = amount
        request_params[:command] = 'PURCHASE'
        request_params[:token_name] = credit_card_token
        request_params[:merchant_reference] = options[:id]
        request_params[:currency] = options[:currency] || default_currency
        request_params[:customer_email] = options[:email]
        request_params[:customer_name] = options[:name] if options.key?(:name)
        request_params[:customer_ip] = options[:ip] if options.key?(:ip)
        request_params[:order_description] = options[:description] if options.key?(:description)
        request_params[:return_url] = options[:return_url] if options.key?(:return_url)
        commit(request_params)
      end

      def credit(amount, funding_source, options = {})
        request_params[:amount] = amount
        request_params[:command] = 'CREDIT'
        false
      end

      def refund(amount, reference, options = {})
        request_params[:amount] = amount
        false
      end

      def verify(payment, options = {})
      end

      def payment_page_params_for(order_id, return_url = nil)
        request_params = {}
        request_params[:service_command] = 'TOKENIZATION'
        request_params[:merchant_reference] = order_id.to_s
        request_params[:return_url] = return_url unless return_url.nil?
        build_request_params(request_params)
      end

      def payment_page_url
        url(:page)
      end

      def process_response(response)
        Response.new(
          success_from(response),
          message_from(response),
          response,
          error_code: response['response_code'],
          fraud_review: valid_signature?(response),
          authorization: authorization_from(response),
          test: test?
        )
      end

      private

      def logger
        @options[:logger] || Logger.new(STDOUT)
      end

      def url(action = :api)
        api_url = (test? ? test_url : live_url)
        uri = if action == :page
                "#{api_url}/paymentPage"
              else
                "#{api_url}/paymentApi"
              end
        uri
      end

      def commit(parameters)
        parameters = build_request_params(parameters)
        post = ssl_post(url, parameters.to_json, headers)
        response = parse(post)
        process_response(response)
      end

      def headers
        {
          'Content-Type' => 'application/json;charset=UTF-8'
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      # Build PayFort request parameters
      def build_request_params(parameters)
        parameters = add_common_parameters(parameters)
        parameters[:signature] = sign(parameters)
        # Stringify all keys and values
        parameters = Hash[parameters.map { |k, v| [k.to_s, v.to_s] }]
        parameters
      end

      # Add common parameters to requests to PayFort
      #
      # ==== Common parameters
      #
      # * <tt>:merchant_identifier</tt>
      # * <tt>:access_code</tt>
      # * <tt>:language</tt>
      # * <tt>:signature</tt>
      def add_common_parameters(parameters)
        common = {
          merchant_identifier: @options[:identifier],
          access_code: @options[:access_code],
          language: 'en'
        }
        parameters.merge!(common)
      end

      # Generate SHA signature for request parameters
      #
      # ==== Steps
      # * Sort parameters alphabetically
      # * Concatenate all parameters into a string
      # * Surround string from previous step with signature_phrase
      # * Generate SHA256 digest for string from previous step
      def sign(parameters)
        phrase = []
        parameters.sort.to_h.each do |k, v|
          phrase << [k, v].join('=')
        end
        phrase.push(@options[:signature_phrase])
        phrase.unshift(@options[:signature_phrase])
        Digest::SHA256.hexdigest(phrase.join)
      end

      def success_from(response)
        SUCCESS_CODES.include?(response['response_code'][0..1])
      end

      def valid_signature?(response)
        sign(response.except('signature')) == response['signature']
      end

      def message_from(response)
        response['response_message']
      end

      def authorization_from(response)
        response['fort_id']
      end
    end
  end
end
