# frozen_string_literal: true

module ActiveMerchant
  module Billing
    module PaypalCommercePlatformCommon
      URLS = {
        test_url: 'https://api.sandbox.paypal.com',
        live_url: 'https://api.paypal.com'
      }.freeze

      ALLOWED_INTENT              = %w[CAPTURE AUTHORIZE].freeze
      ALLOWED_ITEM_CATEGORY       = %w[DIGITAL_GOODS PHYSICAL_GOODS].freeze
      ALLOWED_DISBURSEMENT_MODE   = %w[INSTANT DELAYED].freeze
      ALLOWED_LANDING_PAGE        = %w[LOGIN BILLING NO_PREFERENCE].freeze
      ALLOWED_SHIPPING_PREFERENCE = %w[NO_SHIPPING GET_FROM_FILE SET_PROVIDED_ADDRESS].freeze
      ALLOWED_USER_ACTION         = %w[CONTINUE PAY_NOW].freeze
      ALLOWED_PAYEE_PREFERRED     = %w[UNRESTRICTED IMMEDIATE_PAYMENT_REQUIRED].freeze
      ALLOWED_STANDARD_ENTRIES    = %w[TEL WEB CCD PPD].freeze
      ALLOWED_PAYMENT_INITIATOR   = %w[CUSTOMER MERCHANT].freeze
      ALLOWED_PAYMENT_TYPE        = %w[ONE_TIME RECURRING UNSCHEDULED].freeze
      ALLOWED_USAGE               = %w[FIRST SUBSEQUENT DERIVED].freeze
      ALLOWED_NETWORK             = %w[VISA MASTERCARD DISCOVER AMEX SOLO JCB STAR DELTA SWITCH MAESTRO CB_NATIONALE CONFIGOGA CONFIDIS ELECTRON CETELEM CHINA_UNION_PAY].freeze
      ALLOWED_PHONE_TYPE          = %w[FAX HOME MOBILE OTHER PAGER].freeze
      ALLOWED_TAX_TYPE            = %w[BR_CPF BR_CNPJ].freeze
      ALLOWED_OP_PATCH            = %w[add remove replace move copy test].freeze
      ALLOWED_TOKEN_TYPE          = %w[BILLING_AGREEMENT].freeze
      ALLOWED_PAYMENT_METHOD      = %w[PAYPAL].freeze
      ALLOWED_PLAN_TYPE           = %w[MERCHANT_INITIATED_BILLING MERCHANT_INITIATED_BILLING_SINGLE_AGREEMENT CHANNEL_INITIATED_BILLING CHANNEL_INITIATED_BILLING_SINGLE_AGREEMENT RECURRING_PAYMENTS PRE_APPROVED_PAYMENTS].freeze
      ALLOWED_ACCEPT_PAYMENT_TYPE = %w[INSTANT ECHECK ANY].freeze
      ALLOWED_EXTERNAL_FUNDING    = %w[CREDIT PAY_UPON_INVOICE].freeze

      def initialize(options = {})
        super
      end

      def base_url
        test? ? URLS[:test_url] : URLS[:live_url]
      end

      def commit(method, url, parameters = nil, options = {})
        response               = api_request(method, "#{base_url}/#{url}", parameters, options)
        response['webhook_id'] = options[:webhook_id] if options[:webhook_id]
        success                = success_from(response, options)

        Response.new(
          success,
          message_from(success, response),
          response
        )
      end

      def skip_empty(obj_hsh, key)
        obj_hsh.delete(key) if obj_hsh[key].empty?
      end

      # Prepare API request to hit remote endpoint \
      # to appropriate method(POST, GET, PUT, PATCH).
      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        parameters = parameters.nil? ? nil : parameters.to_json
        begin
          raw_response = ssl_request(method, endpoint, parameters, opt_headers)
          response     = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response     = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def headers(params)
        params[:headers]
      end

      def parse(raw_response)
        raw_response = raw_response.nil? || raw_response.empty? ? '{}' : raw_response
        JSON.parse(raw_response)
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def message_from(success, response)
        success ? 'Transaction Successfully Completed' : response['message']
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the PayPal API. '
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'error' => {
            'message' => msg
          }
        }
      end

      def success_from(response, _options)
        !response.key?('name') && response['debug_id'].nil?
      end

      def get_update_type(path)
        path.split('/').last
      end

      def prepare_request_to_get_access_token(url, options)
        @options = options
        ssl_post_request(url, options)
      end

      def encoded_credentials
        Base64.encode64("#{@options[:authorization][:username]}:#{@options[:authorization][:password]}").gsub("\n", '')
      end

      def return_response(http, request)
        response = http.request(request)
        JSON.parse(response.body)[:access_token]
      end

      def ssl_post_request(url, _options = {})
        @url = url
        url = URI(@url)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        params = {
          grant_type: 'client_credentials'
        }
        url.query = URI.encode_www_form(params)
        request = Net::HTTP::Post.new(url)
        request['accept']           = 'application/json'
        request['accept-language']  = 'en_US'
        request['authorization']    = "basic #{encoded_credentials}"
        request['content-type'] = 'application/x-www-form-urlencoded'

        return_response(http, request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(Authorization: Bearer )\w+-\w+/, '\1[FILTERED]')
                  .gsub(/(Authorization: Basic )\w+=/, '\1[FILTERED]')
                  .gsub(/(payment_source\[card\]\[security_code\]=)\d+/, '\1[FILTERED]')
                  .gsub(/(payment_source\[card\]\[number\]=)\d+/, '\1[FILTERED]')
                  .gsub(/(payment_source\[card\]\[expiry\]=)\d+-\d+/, '\1[FILTERED]')
      end
    end
  end
end
