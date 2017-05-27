require_relative 'genesis/api'
require_relative 'genesis/helpers'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GenesisGateway < Gateway

      include Genesis::TransactionTypes
      include Genesis::TransactionStates
      include Genesis::Helpers::CreditCard

      self.abstract_class      = true

      self.supported_countries = %w(AF AX AL DZ AS AD AO AI AG AR AM AW AU AT AZ BS BH BD
                                    BB BY BE BZ BJ BM BT BO BA BW BR BN BG BF BI KH CM CA
                                    CV KY CF TD CL CN CO KM CG CD CK CR CI HR CU CY CZ DK
                                    DJ DM DO EC EG SV GQ ER EE ET FK FO FJ FI FR GF PF GA
                                    GM GE DE GH GI GR GL GD GP GU GT GG GN GW GY HT VA HN
                                    HK HU IS IN ID IR IQ IE IM IL IT JM JP JE JO KZ KE KI
                                    KP KR KW KG LA LV LB LS LR LY LI LT LU MO MK MG MW MY
                                    MV ML MT MH MQ MR MU YT MX FM MD MC MN MS MA MZ MM NA
                                    NR NP NL NC NZ NI NE NG NU NF MP NO OM PK PW PA PG PY
                                    PE PH PN PL PT PR QA RE RO RU RW RS BL SH KN LC MF PM
                                    VC WS SM ST SA SN SC SL SG SK SI SB SO ZA GS ES LK SD
                                    SR SJ SZ SE CH SY TW TJ TZ TH TG TK TO TT TN TR TM TC
                                    TV UG UA AE GB US UY UZ VU VE VN VG VI WF EH YE ZM ZW)

      self.supported_cardtypes = [:visa, :master, :maestro].freeze
      self.default_currency    = 'USD'.freeze
      self.money_format        = :cents

      AUTH_CREDENTIALS_SEPARATOR = ':'.freeze
      REQUEST_CONTENT_TYPE       = 'application/json'.freeze

      STORING_CARD_UNAVAILABLE_MSG   = 'Storing credit cards is currently unavailable!'.freeze
      UNSTORING_CARD_UNAVAILABLE_MSG = 'Unstoring credit cards is currently unavailable!'.freeze

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

        prepare_referencial_trx_request(Genesis::TransactionTypes::CAPTURE, reference_id)

        process
      end

      def void(reference_id, order_details = {})
        save_order_details(order_details)

        prepare_referencial_trx_request(Genesis::TransactionTypes::VOID, reference_id)

        process
      end

      def credit(money, reference_id, order_details = {})
        ActiveMerchant.deprecated Gateway::CREDIT_DEPRECATION_MESSAGE
        refund(money, reference_id, order_details)
      end

      def refund(money, reference_id, order_details = {})
        save_order_details(order_details)
        add_order_money_details(money)

        prepare_referencial_trx_request(Genesis::TransactionTypes::REFUND, reference_id)

        process
      end

      def verify(credit_card, order_details = {})
        MultiResponse.run(:use_first_response) do |response|
          response.process { authorize(100, credit_card, order_details) }
          response.process(:ignore_result) { void(response.authorization, order_details) }
        end
      end

      def store(*)
        Response.new(false, STORING_CARD_UNAVAILABLE_MSG)
      end

      def unstore(*)
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

      private

      attr_reader   :request_data
      attr_accessor :order_details, :transaction_type

      def process
        response = submit_transaction

        Genesis::Helpers::Response.build_gateway_response(response, test?)
      end

      def submit_transaction
        request_data[:transaction_type] = transaction_type
        raw_response = ssl_post(process_url, request_data.to_json, build_request_headers)
        Genesis::Helpers::Response.parse(raw_response)
      rescue ResponseError => response_error
        raw_response = response_error.response.body
        Genesis::Helpers::Response.build_error_response(raw_response)
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

      def mpi_additional_params_present?
        %w(mpi_eci mpi_xid).all? { |param| request_data[param.to_sym].present? }
      end

      def mpi_params_supplied?
        return false unless request_data[:mpi_cavv].present?

        mpi_additional_params_present?
      end

      def purchase_transaction_type
        return Genesis::TransactionTypes::SALE_3D if mpi_params_supplied?

        Genesis::TransactionTypes::SALE
      end

      def authorize_transaction_type
        return Genesis::TransactionTypes::AUTHORIZE_3D if mpi_params_supplied?

        Genesis::TransactionTypes::AUTHORIZE
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
        return test_url if test?

        live_url
      end

      def process_url
        "#{base_url}/#{options[:token]}"
      end

    end
  end
end
