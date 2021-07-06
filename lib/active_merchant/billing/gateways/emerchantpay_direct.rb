module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EmerchantpayDirectGateway < Gateway

      self.test_url     = 'https://staging-shopify.emerchantpay.com/payments/api/v1/process'
      self.live_url     = 'https://shopify.emerchantpay.com/payments/api/v1/process'

      self.homepage_url = 'https://www.emerchantpay.com/'
      self.display_name = 'eMerchantPay Direct'

      self.ssl_version = :TLSv1_2

      self.supported_countries = %w(AL AD AT BY BE BA BG HR CY CZ DK EE FO FI FR DE GI GR
                                    HU IS IE IM IT RS LV LI LT LU MK MT MD MC ME NL NO PL
                                    PT RO RU SM RS SK SI ES SE CH UA GB VA RS)

      self.supported_cardtypes = [:visa, :master, :maestro].freeze
      self.default_currency    = 'USD'.freeze
      self.money_format        = :cents

      APPROVED = 'approved'.freeze
      DECLINED = 'declined'.freeze
      ERROR    = 'error'.freeze

      SALE         = 'sale'.freeze
      SALE_3D      = 'sale3d'.freeze
      AUTHORIZE    = 'authorize'.freeze
      AUTHORIZE_3D = 'authorize3d'.freeze
      CAPTURE      = 'capture'.freeze
      REFUND       = 'refund'.freeze
      VOID         = 'void'.freeze

      AUTH_CREDENTIALS_SEPARATOR = ':'.freeze
      REQUEST_CONTENT_TYPE       = 'application/json'.freeze

      STORING_CARD_UNAVAILABLE_MSG   = 'Storing credit cards is currently unavailable!'.freeze
      UNSTORING_CARD_UNAVAILABLE_MSG = 'Unstoring credit cards is currently unavailable!'.freeze

      RESPONSE_ERROR_CODES = {
        undefined_error:                  1,
        invalid_request:                  11,
        merchant_login_failed:            12,
        merchant_not_configured:          13,
        invalid_transaction_param:        14,
        transaction_not_allowed:          15,
        system_error:                     100,
        maintenance_error:                101,
        authentication_error:             110,
        configuration_error:              120,
        communication_error:              200,
        connection_error:                 210,
        account_error:                    220,
        timeout_error:                    230,
        response_error:                   240,
        parsing_error:                    250,
        input_data_error:                 300,
        invalid_transaction_type_error:   310,
        input_data_missing_error:         320,
        input_data_format_error:          330,
        input_data_invalid_error:         340,
        invalid_xml_error:                350,
        invalid_content_type_error:       360,
        workflow_error:                   400,
        reference_not_found_error:        410,
        reference_workflow_error:         420,
        reference_invalidated_error:      430,
        reference_mismatch_error:         440,
        double_transaction_error:         450,
        txn_not_found_error:              460,
        processing_error:                 500,
        invalid_card_error:               510,
        expired_card_error:               520,
        transaction_pending_error:        530,
        credit_exceeded_error:            540,
        risk_error:                       600,
        bin_country_check_error:          609,
        card_blacklist_error:             610,
        bin_blacklist_error:              611,
        country_blacklist_error:          612,
        ip_blacklist_error:               613,
        blacklist_error:                  614,
        card_whitelist_error:             615,
        card_limit_exceeded_error:        620,
        terminal_limit_exceeded_error:    621,
        contract_limit_exceeded_error:    622,
        card_velocity_exceeded_error:     623,
        card_ticket_size_exceeded_error:  624,
        user_limit_exceeded_error:        625,
        multiple_failure_detection_error: 626,
        cs_detection_error:               627,
        recurring_limit_exceeded_error:   628,
        avs_error:                        690,
        max_mind_risk_error:              691,
        threat_metrix_risk_error:         692,
        remote_error:                     900,
        remote_system_error:              910,
        remote_configuration_error:       920,
        remote_data_error:                930,
        remote_workflow_error:            940,
        remote_timeout_error:             950,
        remote_connection_error:          960
      }.freeze

      ISSUER_RESPONSE_ERROR_CODES = {
        approved:                 '00',
        card_issue:               '02',
        invalid_merchant:         '03',
        invalid_txn_for_terminal: '06'
      }.freeze

      FRAUDULENT_ERROR_CODES = [
        RESPONSE_ERROR_CODES[:risk_error],
        RESPONSE_ERROR_CODES[:max_mind_risk_error],
        RESPONSE_ERROR_CODES[:threat_metrix_risk_error]
      ].freeze

      GATEWAY_CONFIG_ERROR_CODES = [
        RESPONSE_ERROR_CODES[:undefined_error],
        RESPONSE_ERROR_CODES[:invalid_request],
        RESPONSE_ERROR_CODES[:merchant_login_failed],
        RESPONSE_ERROR_CODES[:merchant_not_configured],
        RESPONSE_ERROR_CODES[:invalid_transaction_param],
        RESPONSE_ERROR_CODES[:transaction_not_allowed],
        RESPONSE_ERROR_CODES[:txn_not_found_error]
      ].freeze

      REVERSED_TRANSACTIONS = [
        REFUND,
        VOID
      ].freeze

      API_RESPONSE_ERROR_CODE_MAPPING = {
        RESPONSE_ERROR_CODES[:system_error]             => :processing_error,
        RESPONSE_ERROR_CODES[:authentication_error]     => :processing_error,
        RESPONSE_ERROR_CODES[:input_data_error]         => :processing_error,
        RESPONSE_ERROR_CODES[:input_data_missing_error] => :processing_error,
        RESPONSE_ERROR_CODES[:processing_error]         => :card_declined,
        RESPONSE_ERROR_CODES[:invalid_card_error]       => :card_declined,
        RESPONSE_ERROR_CODES[:expired_card_error]       => :expired_card,
        RESPONSE_ERROR_CODES[:card_black_list_error]    => :card_declined,
        RESPONSE_ERROR_CODES[:avs_error]                => :incorrect_address
      }.freeze

      INVALID_GATEWAY_RESPONSE_MSG = 'Invalid response received from the Gateway API.'.freeze
      CONTACT_SUPPORT_TEAM_MSG     = 'Please contact support team.'.freeze
      RESPONSE_DESCRIPTION_MSG     = 'The raw response returned by the API was'.freeze

      def initialize(options = {})
        requires!(options, :username, :password, :token)
        @request_data = {}

        super
      end

      def purchase(money, credit_card, order_details = {})
        save_order_details(order_details)
        add_order_money_details(money)

        prepare_initial_trx_request(:purchase, credit_card)

        process
      end

      def authorize(money, credit_card, order_details = {})
        save_order_details(order_details)
        add_order_money_details(money)

        prepare_initial_trx_request(:authorize, credit_card)

        process
      end

      def capture(money, reference_id, order_details = {})
        save_order_details(order_details)
        add_order_money_details(money)

        prepare_referencial_trx_request(EmerchantpayDirectGateway::CAPTURE, reference_id)

        process
      end

      def void(reference_id, order_details = {})
        save_order_details(order_details)

        prepare_referencial_trx_request(EmerchantpayDirectGateway::VOID, reference_id)

        process
      end

      def credit(money, reference_id, order_details = {})
        ActiveMerchant.deprecated Gateway::CREDIT_DEPRECATION_MESSAGE

        refund(money, reference_id, order_details)
      end

      def refund(money, reference_id, order_details = {})
        save_order_details(order_details)
        add_order_money_details(money)

        prepare_referencial_trx_request(EmerchantpayDirectGateway::REFUND, reference_id)

        process
      end

      def verify(credit_card, order_details = {})
        MultiResponse.run(:use_first_response) do |response|
          response.process { authorize(100, credit_card, order_details) }
          response.process(:ignore_result) { void(response.authorization, order_details) }
        end
      end

      def store(credit_card, order_details = {})
        Response.new(false, STORING_CARD_UNAVAILABLE_MSG)
      end

      def unstore(authorization, order_details = {})
        Response.new(false, UNSTORING_CARD_UNAVAILABLE_MSG)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(Authorization: Basic )\w+/, '\1[FILTERED]')
          .gsub(/(card_number\\?":\\?")[^"\\]*/i, '\1[FILTERED]')
          .gsub(/(cvv\\?":\\?")\d+[^"\\]*/i, '\1[FILTERED]')
          .gsub(/(cvv\\?":)null/, '\1[BLANK]')
          .gsub(/(cvv\\?":\\?")\\?"/, '\1[BLANK]"')
          .gsub(/(cvv\\?":\\?")\s+/, '\1[BLANK]')
      end

      def supports_network_tokenization?
        true
      end

      def map_error_code(error_code)
        return :processing_error unless API_RESPONSE_ERROR_CODE_MAPPING.key?(error_code)

        API_RESPONSE_ERROR_CODE_MAPPING[error_code]
      end

      def reversed_transaction?(transaction_type)
        REVERSED_TRANSACTIONS.include?(transaction_type)
      end

      def configuration_error?(response_error_code)
        GATEWAY_CONFIG_ERROR_CODES.include?(response_error_code)
      end

      private

      attr_reader   :request_data
      attr_accessor :order_details, :transaction_type

      def process
        response = submit_transaction

        build_gateway_response(response)
      end

      def submit_transaction
        request_data[:transaction_type] = transaction_type

        raw_response = ssl_post(process_url, request_data.to_json, build_request_headers)
        parse_response(raw_response)
      rescue ResponseError => response_error
        raw_response = response_error.response.body
        build_error_response(raw_response)
      end

      def prepare_initial_trx_request(method, credit_card)
        requires!(order_details, :order_id)

        add_currency_amount
        add_remote_ip
        add_usage
        add_invoice
        add_credit_card(credit_card)
        add_address

        @transaction_type = method_transaction_type(method)
      end

      def prepare_referencial_trx_request(transaction_type, reference_id)
        order_details[:reference_id] = reference_id
        @transaction_type            = transaction_type

        add_reference_id
        add_currency_amount
        add_remote_ip
        add_usage
      end

      def method_transaction_type(method)
        return purchase_transaction_type if method == :purchase

        authorize_transaction_type
      end

      def save_order_details(order_details)
        @order_details = order_details
      end

      def add_order_money_details(money)
        order_details[:money] = money
      end

      def order_money_details_supplied?
        order_details[:money].present?
      end

      def add_reference_id
        request_data[:reference_id] = order_details[:reference_id]
      end

      def add_remote_ip
        request_data[:remote_ip] = order_details[:ip]
      end

      def add_currency_amount
        return unless order_money_details_supplied?

        request_data[:amount]   = order_amount
        request_data[:currency] = order_currency
      end

      def add_usage
        add_optional_request_data_item(:usage, :description)
      end

      def add_invoice
        %w(merchant order_id invoice device_session_id).each do |request_key|
          add_optional_request_data_item(request_key)
        end
      end

      def add_optional_request_data_item(request_key, order_details_key = nil)
        order_details_key = request_key unless order_details_key
        order_detail      = order_details[order_details_key.to_sym]

        request_data[request_key.to_sym] = order_detail if order_detail
      end

      def add_mpi_params(credit_card)
        return unless credit_card_supports_mpi_params?(credit_card)

        request_data[:mpi_cavv] = credit_card.payment_cryptogram
        request_data[:mpi_eci]  = credit_card.eci
        request_data[:mpi_xid]  = credit_card.transaction_id
      end

      def add_credit_card(credit_card)
        request_data[:card_holder]      = credit_card.name
        request_data[:card_number]      = credit_card.number
        request_data[:expiration_month] = credit_card_expiration_month(credit_card)
        request_data[:expiration_year]  = credit_card.year
        request_data[:cvv]              = credit_card.verification_value

        add_mpi_params(credit_card)
      end

      def add_address
        request_data[:customer]       = order_details[:customer]
        request_data[:customer_email] = order_details[:email]

        add_billing_address
        add_shipping_address
      end

      def add_billing_address
        billing_address = order_details[:billing_address] || order_details[:address]

        return unless billing_address

        request_data[:customer_phone] = billing_address[:phone]

        billing_first_name, billing_last_name = split_address_names(billing_address)

        request_data[:billing_full_name]  = billing_address[:name] if billing_address.key?(:name)
        request_data[:billing_first_name] = billing_first_name
        request_data[:billing_last_name]  = billing_last_name
        request_data[:billing_address1]   = billing_address[:address1]
        request_data[:billing_address2]   = billing_address[:address2]
        request_data[:billing_company]    = billing_address[:company]
        request_data[:billing_zip_code]   = billing_address[:zip]
        request_data[:billing_city]       = billing_address[:city]
        request_data[:billing_state]      = billing_address[:state]
        request_data[:billing_country]    = billing_address[:country]
      end

      def add_shipping_address
        shipping_address = order_details[:shipping_address] || order_details[:address]

        return unless shipping_address

        shipping_first_name, shipping_last_name = split_address_names(shipping_address)

        request_data[:shipping_full_name]  = shipping_address[:name] if shipping_address.key?(:name)
        request_data[:shipping_first_name] = shipping_first_name
        request_data[:shipping_last_name]  = shipping_last_name
        request_data[:shipping_address1]   = shipping_address[:address1]
        request_data[:shipping_address2]   = shipping_address[:address2]
        request_data[:shipping_company]    = shipping_address[:company]
        request_data[:shipping_zip_code]   = shipping_address[:zip]
        request_data[:shipping_city]       = shipping_address[:city]
        request_data[:shipping_state]      = shipping_address[:state]
        request_data[:shipping_country]    = shipping_address[:country]
      end

      def credit_card_supports_mpi_params?(credit_card)
        credit_card.is_a?(NetworkTokenizationCreditCard)
      end

      def credit_card_expiration_month(credit_card)
        credit_card.month.to_s.rjust(2, '0')
      end

      def mpi_params_supplied?
        %w(mpi_cavv mpi_eci mpi_xid).all? { |param| request_data[param.to_sym].present? }
      end

      def purchase_transaction_type
        mpi_params_supplied? ? SALE_3D : SALE
      end

      def authorize_transaction_type
        mpi_params_supplied? ? AUTHORIZE_3D : AUTHORIZE
      end

      def split_address_names(address)
        return split_names(address[:name]) if address.key?(:name)

        [address[:first_name], address[:last_name]]
      end

      def build_request_headers
        {
          'Content-Type'        => REQUEST_CONTENT_TYPE,
          'Authorization'       => build_auth_credentials,
          'User-Agent'          => gateway_user_agent,
          'X-Client-User-Agent' => user_agent
        }
      end

      def build_auth_credentials
        username  = options[:username]
        password  = options[:password]
        separator = AUTH_CREDENTIALS_SEPARATOR

        credentials = "#{username}#{separator}#{password}"
        "Basic #{Base64.strict_encode64(credentials).strip}"
      end

      def gateway_user_agent
        "#{self.class}/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
      end

      def order_amount
        amount(order_details[:money])
      end

      def order_currency
        order_details[:currency] || currency(order_details[:money]).upcase
      end

      def base_url
        test? ? test_url : live_url
      end

      def process_url
        "#{base_url}/#{options[:token]}"
      end

      def build_gateway_response(response)
        Response.new(response_processed?(response),
                     response['message'],
                     response,
                     test:          test?,
                     authorization: unique_id(response),
                     fraud_review:  fraud_detected?(response),
                     error_code:    error_code(response))
      end

      def unique_id(response)
        return unless transaction_approved?(response)

        response['unique_id'] unless reversed_transaction?(response['transaction_type'])
      end

      def error_code(response)
        map_error_code(response['code']) unless response_processed?(response)
      end

      def parse_response(raw_response)
        parse_json(raw_response)
      rescue JSON::ParserError
        build_error_response(raw_response)
      end

      def fraud_detected?(response)
        return false if response_processed?(response)

        FRAUDULENT_ERROR_CODES.include?(response['code'])
      end

      def response_processed?(response)
        return false if response.key?('code')

        transaction_approved?(response)
      end

      def build_error_response(response_body)
        {
          'message' => build_invalid_response_message(response_body)
        }
      end

      def parse_json(body)
        return {} unless body

        JSON.parse(body)
      end

      def transaction_approved?(response)
        return false unless response.key?('status')

        response['status'] == APPROVED
      end

      def build_invalid_response_message(response_body)
        invalid_response_prefix = "#{INVALID_GATEWAY_RESPONSE_MSG}#{CONTACT_SUPPORT_TEAM_MSG}"

        "#{invalid_response_prefix} #{RESPONSE_DESCRIPTION_MSG} #{response_body}"
      end

    end
  end
end
