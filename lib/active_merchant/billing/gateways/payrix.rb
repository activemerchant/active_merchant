module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayrixGateway < Gateway
      self.test_url = 'https://sandbox.rest.paymentsapi.io'
      self.live_url = 'https://rest.paymentsapi.io'

      class_attribute :test_auth_url
      self.test_auth_url = 'https://sandbox.auth.paymentsapi.io/login'

      class_attribute :auth_url
      self.auth_url = 'https://auth.paymentsapi.io/login'

      self.supported_countries = %w[US AU NZ]
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]
      self.money_format = :dollars

      self.homepage_url = 'https://www.payrix.com/'
      self.display_name = 'Payrix'

      STANDARD_ERROR_CODE_MAPPING = {
        'EXPIRED' => STANDARD_ERROR_CODE[:expired_card],
        'FRAUD_CHECK_DECLINE' => STANDARD_ERROR_CODE[:invalid_cvc],
        'FRAUD_CHECK_ERROR' => STANDARD_ERROR_CODE[:processing_error],
        'ERROR' => STANDARD_ERROR_CODE[:processing_error],
        'BadRequest' => STANDARD_ERROR_CODE[:processing_error],
        'FunctionNotAllowed' => STANDARD_ERROR_CODE[:unsupported_feature],
        'InternalServerError' => STANDARD_ERROR_CODE[:processing_error],
        'InvalidApiToken' => STANDARD_ERROR_CODE[:config_error]
      }

      TRANSACTION_TYPES = {
        # Full sale - Funds are fully collected and ready to be settled to your business
        purchase: 'COMPLETE',
        # Pre-authorisation only - Funds are reserved on the person's card and will not be collected until you use the Capture function. Pre-auths that aren't captured automatically expire (usually occurs within 2-3 days)
        authorize: 'PREAUTH',
        # This allows you to perform a zero-dollar pre-authorisation for the purpose of checking that a particular card is valid and active.
        # It also assists in meeting card-on-file storage obligations, and customer-initiated-transaction/merchant-initiated-transaction mandates, by allowing you to verify a card using customer authentication before storage, and obtain a reference that can be provided with future recurring transactions on that card to link them to the initial authorisation.
        verify: 'VERIFY'
      }

      ENDPOINTS = {
        hpp: 'hpp/',
        eddr: 'eddr/',
        vault: 'vault/',
        access_token: 'login'
      }

      TOKEN_STATUS = {
        waiting: 'WAITING',
        validated: 'VALIDATED',
        processed_successful: 'PROCESSED_SUCCESSFUL',
        processed_rejected: 'PROCESSED_REJECTED',
        cancelled: 'CANCELLED',
        error: 'ERROR',
        fraud_check_decline: 'FRAUD_CHECK_DECLINE',
        fraud_check_error: 'FRAUD_CHECK_ERROR',
        expired: 'EXPIRED'
      }

      TOKEN_STATUS_DESCRIPTIONS = {
        'WAITING' => 'Token URL not yet accessed',
        'VALIDATED' => 'Token URL loaded',
        'PROCESSED_SUCCESSFUL' => 'URL completed successfully',
        'PROCESSED_REJECTED' => 'URL Opened, not completed and closed',
        'CANCELLED' => 'URL Completed but cancelled on confirmation page',
        'ERROR' => 'Internal error received',
        'FRAUD_CHECK_DECLINE' =>
          'Payment attempted but declined by Fraud check',
        'FRAUD_CHECK_ERROR' =>
          'Payment attempted but Fraud Check error received',
        'EXPIRED' => 'Token has expired and is no longer useable'
      }

      def initialize(options = {})
        requires!(options, :login, :password, :business_id)

        @business_id = options[:business_id]
        @service = (options[:service]&.to_sym || :hpp)
        @token = nil

        unless ENDPOINTS.key?(@service)
          raise ArgumentError, "Unsupported service `#{@service}'."
        end

        super
      end

      def setup_purchase(money, options = {})
        requires!(options, :return_url, :transaction_reference)
        requires!(options, :unique_reference, :name) if store?

        post = new_post

        add_transaction(post, money, options)
        add_customer_data(post, options)
        add_address(post, options)
        add_template(post, options)
        add_audit(post, options)
        add_return_url(post, options)

        MultiResponse.run do |r|
          r.process { commit :access_token, create_access_token_request }
          r.process { commit :purchase, post, access_token: access_token(r) }
        end.primary_response
      end

      def setup_authorize(money, options = {})
        requires!(options, :return_url, :transaction_reference)
        requires!(options, :unique_reference, :name) if store?

        post = new_post

        add_transaction(post, money, options)
        add_customer_data(post, options)
        add_address(post, options)
        add_template(post, options)
        add_audit(post, options)
        add_return_url(post, options)

        MultiResponse.run do |r|
          r.process { commit :access_token, create_access_token_request }
          r.process { commit :authorize, post, access_token: access_token(r) }
        end.primary_response
      end

      def setup_verify(options = {})
        requires!(options, :return_url, :transaction_reference)
        requires!(options, :unique_reference, :name) if store?

        post = new_post

        # add_transaction(post, money, options)
        add_customer_data(post, options)
        add_address(post, options)
        add_template(post, options)
        add_audit(post, options)
        add_return_url(post, options)

        MultiResponse.run do |r|
          r.process { commit :access_token, create_access_token_request }
          r.process { commit :verify, post, access_token: access_token(r) }
        end.primary_response
      end

      # Swap token for details about success / failure of transaction
      def details_for(token_id)
        payload = { id: token_id }

        MultiResponse.run do |r|
          r.process { commit :access_token, create_access_token_request }
          r.process { commit :token, payload, access_token: access_token(r) }
        end.primary_response
      end

      private

      def new_post
        { payer: {}, transaction: {} }
      end

      def add_transaction(post, money, options)
        t = post[:transaction]

        t[:reference] = trim(options[:transaction_reference])
        t[:description] = options[:description] || ''
        t[:amount] = amount(money)
        t[:currency_code] = (options[:currency] || currency(money))

        post[:transaction] = t
      end

      def add_customer_data(post, options)
        payer = post[:payer]

        payer[:save_payer] = (options[:store] || false)
        payer[:unique_reference] = trim(options[:customer_reference]) if store?
        payer[:group_reference] = trim(options[:group_reference]) if store?
        payer[:family_or_business_name] = options[:name] if store?
        payer[:email] = options[:email]
        payer[:phone] = options[:phone]
        payer[:mobile] = options[:mobile]
        payer[:date_of_birth] = options[:date_of_birth]

        post[:payer] = payer
      end

      def add_address(post, options)
        if (address = (options[:billing_address] || options[:address]))
          post[:payer].tap do |h|
            h[:address] = {}
            h[:address][:line1] = address[:address1] if address[:address1]
            h[:address][:line2] = address[:address2] if address[:address2]
            h[:address][:state] = address[:state] if address[:state]
            h[:address][:country] = address[:country] if address[:country]
            h[:address][:post_code] = address[:zip] if address[:zip]
          end
        end
      end

      def add_template(post, options)
        post[:template] = (options[:template] || 'Basic')
      end

      def add_audit(post, options)
        return unless options[:ip].present?

        post[:audit] = {}
        post[:audit][:user_i_p] = options[:ip]
      end

      def add_return_url(post, options)
        post[:return_url] = options[:return_url]
      end

      def parse(body)
        JSON.parse(body).deep_transform_keys { |key| key.underscore.to_sym }
      end

      def headers(options = {})
        headers = {}
        headers['Authorization'] =
          "Bearer #{options[:access_token]}" if options[:access_token]
        headers['Content-Type'] = 'application/json'
        headers
      end

      def commit(action, parameters, options = {})
        url =
          build_url(
            action,
            parameters.merge(service: options[:service] || @service)
          )

        begin
          response =
            parse(
              ssl_request(
                verb(action),
                url,
                post_data(action, parameters),
                headers(options)
              )
            )
        rescue ResponseError => e
          # No gateway error message so we throw
          raise if e.response.body.blank?

          response = parse(e.response.body)
        end

        if action == :token
          PayrixResponse.new(
            token_success_from(response),
            token_message_from(response),
            response,
            error_code: token_error_code_from(response),
            fraud_review: token_fraud_review_from(response),
            test: test?
          )
        else
          PayrixResponse.new(
            success_from(response),
            message_from(response),
            response,
            error_code: error_code_from(response),
            test: test?
          )
        end
      end

      def create_access_token_request
        { username: options[:login], password: options[:password] }
      end

      def verb(action)
        return :get if action == :token

        :post
      end

      def build_url(action, parameters)
        return test? ? test_auth_url : auth_url if action == :access_token

        base_url = (test? ? test_url : live_url)
        endpoint = ENDPOINTS[@service]
        endpoint = parameters[:id] if parameters[:id] && action == :token

        "#{base_url}/businesses/#{@business_id}/services/tokens/#{endpoint}"
      end

      def success_from(response)
        !response.key?(:error_code)
      end

      def message_from(response)
        success_from(response) ? 'Succeeded' : response[:error_message]
      end

      def authorization_from(response)
        nil
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response[:error_code]] ||
            response[:error_code].to_s.underscore
        end
      end

      def token_error_code_from(response)
        unless token_success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response[:status]] || response[:status]
        end
      end

      def token_success_from(response)
        response[:status] == TOKEN_STATUS[:processed_successful]
      end

      def token_message_from(response)
        TOKEN_STATUS_DESCRIPTIONS[response[:status_description]] ||
          response[:status_description]
      end

      def token_fraud_review_from(response)
        response[:status] == TOKEN_STATUS[:fraud_check_decline]
      end

      def access_token(r)
        r.params.dig('access_token')
      end

      def post_data(action, parameters = {})
        return nil if verb(action) == :get

        if TRANSACTION_TYPES[action]
          parameters[:transaction][:process_type] = TRANSACTION_TYPES[action]
        end

        parameters.deep_transform_keys { |key| key.to_s.camelize }.to_json
      end

      def trim(str, length = 100)
        truncate(str, length)
      end

      def store?
        !!@options[:store]
      end

      class PayrixResponse < Response
        def token
          @params['token']
        end

        def redirect_url
          @params['redirect_to_url']
        end
      end
    end
  end
end
