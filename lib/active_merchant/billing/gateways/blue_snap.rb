require 'nokogiri'

module ActiveMerchant
  module Billing
    class BlueSnapGateway < Gateway
      self.test_url = 'https://sandbox.bluesnap.com/services/2'
      self.live_url = 'https://ws.bluesnap.com/services/2'
      self.supported_countries = %w(US CA GB AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE AR BO BR BZ CL CO CR DO EC GF GP GT HN HT MF MQ MX NI PA PE PR PY SV UY VE)

      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover jcb diners_club maestro naranja cabal]
      self.currencies_without_fractions = %w(BYR CLP ILS JPY KRW VND XOF)

      self.homepage_url = 'https://home.bluesnap.com/'
      self.display_name = 'BlueSnap'

      API_VERSION = '3.0'

      TRANSACTIONS = {
        purchase: 'AUTH_CAPTURE',
        authorize: 'AUTH_ONLY',
        capture: 'CAPTURE',
        void: 'AUTH_REVERSAL',
        refund: 'REFUND',
        update: 'UPDATE',
      }

      CVC_CODE_TRANSLATOR = {
        'MA' => 'M',
        'NC' => 'U',
        'ND' => 'P',
        'NM' => 'N',
        'NP' => 'S'
      }

      AVS_CODE_TRANSLATOR = {
        'line1: U, zip: U, name: U' => 'I',
        'line1: U, zip: U, name: M' => 'I',
        'line1: U, zip: U, name: N' => 'I',
        'line1: U, zip: M, name: U' => 'P',
        'line1: U, zip: M, name: M' => 'P',
        'line1: U, zip: M, name: N' => 'F',
        'line1: U, zip: N, name: U' => 'O',
        'line1: U, zip: N, name: M' => 'O',
        'line1: U, zip: N, name: N' => 'O',
        'line1: M, zip: U, name: U' => 'B',
        'line1: M, zip: U, name: M' => 'B',
        'line1: M, zip: U, name: N' => 'T',
        'line1: M, zip: M, name: U' => 'M',
        'line1: M, zip: M, name: M' => 'V',
        'line1: M, zip: M, name: N' => 'H',
        'line1: M, zip: N, name: U' => 'A',
        'line1: M, zip: N, name: M' => 'O',
        'line1: M, zip: N, name: N' => 'A',
        'line1: N, zip: U, name: U' => 'C',
        'line1: N, zip: U, name: M' => 'C',
        'line1: N, zip: U, name: N' => 'C',
        'line1: N, zip: M, name: U' => 'W',
        'line1: N, zip: M, name: M' => 'L',
        'line1: N, zip: M, name: N' => 'W',
        'line1: N, zip: N, name: U' => 'N',
        'line1: N, zip: N, name: M' => 'K',
        'line1: N, zip: N, name: N' => 'N',
      }

      BANK_ACCOUNT_TYPE_MAPPING = {
        'personal_checking' => 'CONSUMER_CHECKING',
        'personal_savings' => 'CONSUMER_SAVINGS',
        'business_checking' => 'CORPORATE_CHECKING',
        'business_savings' => 'CORPORATE_SAVINGS'
      }

      STATE_CODE_COUNTRIES = %w(US CA)

      def initialize(options={})
        requires!(options, :api_username, :api_password)
        super
      end

      def purchase(money, payment_method, options={})
        payment_method_details = PaymentMethodDetails.new(payment_method)

        if payment_method_details.alt_transaction?
          commit(:purchase, :post, payment_method_details) do |doc|
            add_alt_transaction_purchase(doc, money, payment_method_details, options)
          end
        elsif options[:subscription_id].blank?
          raise ActiveMerchantError.new("Unable to purchase without a subscription")
        else
          commit(:charge_subscription, :post, payment_method_details, options) do |doc|
            add_amount(doc, money, options)
            add_charge_description(doc, options[:description])
          end
        end
      end

      def authorize(money, payment_method, options={})
        commit(:authorize) do |doc|
          add_auth_only(doc, money, payment_method, options)
        end
      end

      def payment_fields_token
        commit(:get_payment_fields_token)
      end

      def capture(money, authorization, options={})
        commit(:capture, :put) do |doc|
          doc.send('card-transaction-type', 'CAPTURE')
          add_authorization(doc, authorization)
          add_order(doc, options)
          add_amount(doc, money, options) if options[:include_capture_amount] == true
        end
      end

      def refund(money, authorization, options={})
        commit(:refund, :put) do
          { authorization: authorization, money: amount(money) }
        end
      end

      def void(authorization, options={})
        commit(:refund, :put) do
          { authorization: authorization }
        end
      end

      def verify(payment_method, options={})
        authorize(0, payment_method, options)
      end

      def store(payment_method, options = {})
        payment_method_details = PaymentMethodDetails.new(payment_method)

        MultiResponse.run do |r|
          r.process do
            commit(:store, :post, payment_method_details) do |doc|
              add_personal_info(doc, payment_method, options)
              add_fraud_info(doc, options)
              add_echeck_company(doc, payment_method) if payment_method_details.check?
              doc.send('payment-sources') do
                payment_method_details.check? ? store_echeck(doc, payment_method) : store_credit_card(doc, payment_method)
              end
              add_3ds(doc, options[:three_d_secure])
              add_order(doc, options)
            end
          end

          if r.responses.last.success? && payment_method_details.card_transaction?
            options[:last_four] = r.responses.last.params["card-last-four-digits"]
            options[:card_type] = r.responses.last.params["card-type"]
            options[:vaulted_shopper_id] = r.responses.last.params["vaulted-shopper-id"]
            r.process do
              create_subscription(options)
            end
          end
        end
      end

      def create_subscription(options = {})
        commit(:create_subscription, :post) do |doc|
          add_vaulted_shopper_id(doc, options[:vaulted_shopper_id])
          add_credit_card_info(doc, options)
          add_fraud_info(doc, options)
          add_3ds(doc, options[:three_d_secure])
          add_order(doc, options)
          doc.send('currency', options[:currency])
        end
      end

      def store_credit_card(doc, payment_method)
        doc.send('credit-card-info') do
          add_credit_card(doc, payment_method)
        end
      end

      def store_echeck(doc, payment_method)
        doc.send('ecp-details') do
          doc.send('ecp') do
            add_echeck(doc, payment_method)
          end
        end
      end

      def update(payment_method, options= {})
        payment_method_details = PaymentMethodDetails.new(payment_method)
        payment_method_details.vaulted_shopper_id = options[:vaulted_shopper_id] if options[:vaulted_shopper_id].present?
        commit(:update, :put, payment_method_details) do |doc|
          doc.send('first-name', payment_method.first_name)
          doc.send('last-name', payment_method.last_name)
          doc.email(options[:email]) if options[:email]
        end
      end

      def retrieve(vault_token, options = {})
        action = :retrieve
        payment_method_details = PaymentMethodDetails.new(vault_token)
        response = api_request(action, nil, :get, payment_method_details, nil)

        parsed = parse(response, action)

        succeeded = success_from(action, response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          parsed,
          authorization: authorization_from(action, parsed, payment_method_details),
          avs_result: avs_result(parsed),
          cvv_result: cvv_result(parsed),
          error_code: error_code_from(parsed),
          test: test?
        )
      end

      def verify_credentials
        begin
          ssl_get(url.to_s, headers)
        rescue ResponseError => e
          return false if e.response.code.to_i == 401
        end

        true
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<card-number>).+(</card-number>)), '\1[FILTERED]\2').
          gsub(%r((<security-code>).+(</security-code>)), '\1[FILTERED]\2').
          gsub(%r((<(?:public-)?account-number>).+(</(?:public-)?account-number>)), '\1[FILTERED]\2').
          gsub(%r((<(?:public-)?routing-number>).+(</(?:public-)?routing-number>)), '\1[FILTERED]\2')
      end

      private

      def add_vaulted_shopper_id(doc, payment_method)
        doc.send('vaulted-shopper-id', payment_method)
      end

      def add_credit_card_info(doc, options)
        doc.send('payment-source') do
          doc.send('credit-card-info') do
            doc.send('credit-card') do
              doc.send('card-last-four-digits', options[:last_four])
              doc.send('card-type', options[:card_type])
            end
          end
        end
      end

      def add_auth_purchase(doc, money, payment_method, options)
        doc.send('card-transaction-type', 'AUTH_CAPTURE')
        add_order(doc, options)
        doc.send('store-card', options[:store_card] || false)
        add_amount(doc, money, options)
        add_fraud_info(doc, options)

        if payment_method.is_a?(String)
          doc.send('vaulted-shopper-id', payment_method)
          add_stored_card_info(doc, options)
        else
          doc.send('card-holder-info') do
            add_personal_info(doc, payment_method, options)
          end
          add_credit_card(doc, payment_method)
        end
      end

      def add_auth_only(doc, money, payment_method, options)
        doc.send('card-transaction-type', 'AUTH_ONLY')
        add_order(doc, options)
        add_3ds(doc, options[:three_d_secure])
        doc.send('store-card', options[:store_card] || false)
        add_amount(doc, money, options)
        add_fraud_info(doc, options)

        if payment_method.is_a?(String)
          doc.send('vaulted-shopper-id', payment_method)
        else
          doc.send('card-holder-info') do
            add_personal_info(doc, payment_method, options)
          end
          add_credit_card(doc, payment_method)
        end
      end

      def add_amount(doc, money, options)
        currency = options[:currency] || currency(money)
        doc.amount(localized_amount(money, currency))
        doc.currency(currency)
      end

      def add_personal_info(doc, payment_method, options)
        doc.send('first-name', payment_method.first_name)
        doc.send('last-name', payment_method.last_name)
        doc.send('personal-identification-number', options[:personal_identification_number]) if options[:personal_identification_number]
        doc.email(options[:email]) if options[:email]
        add_address(doc, options)
      end

      def add_credit_card(doc, card)
        doc.send('credit-card') do
          doc.send('card-number', card.number)
          doc.send('security-code', card.verification_value)
          doc.send('expiration-month', card.month)
          doc.send('expiration-year', card.year)
        end
      end

      def add_stored_card_info(doc, options)
        doc.send('credit-card') do
          doc.send('card-last-four-digits', options[:last_four])
          doc.send('card-type', options[:card_type])
        end
      end

      def add_description(doc, description)
        doc.send('transaction-meta-data') do
          doc.send('meta-data') do
            doc.send('meta-description', description)
          end
        end
      end

      def add_charge_description(doc, description)
        doc.send('charge-info') do
          doc.send('charge-description', description)
        end
      end

      def add_order(doc, options)
        doc.send('merchant-transaction-id', truncate(options[:order_id], 50)) if options[:order_id]
        doc.send('soft-descriptor', options[:soft_descriptor]) if options[:soft_descriptor]
        add_level_3_data(doc, options)
      end

      def add_address(doc, options)
        address = options[:billing_address]
        return unless address

        doc.country(address[:country]) if address[:country]
        doc.state(address[:state]) if address[:state] && STATE_CODE_COUNTRIES.include?(address[:country])
        doc.address(address[:address]) if address[:address]
        doc.city(address[:city]) if address[:city]
        doc.zip(address[:zip]) if address[:zip]
      end

      def add_3ds(doc, three_d_secure_options)
        return unless three_d_secure_options

        eci = three_d_secure_options[:eci]
        cavv = three_d_secure_options[:cavv]
        xid = three_d_secure_options[:xid]
        ds_transaction_id = three_d_secure_options[:ds_transaction_id]
        version = three_d_secure_options[:version]
        three_d_secure_reference_id = three_d_secure_options[:three_d_secure_reference_id]
        three_d_secure_result_token = three_d_secure_options[:three_d_secure_result_token]

        doc.send('three-d-secure') do
          doc.send('eci', eci) if eci
          doc.send('cavv', cavv) if cavv
          doc.send('xid', xid) if xid
          doc.send('three-d-secure-version', version) if version
          doc.send('ds-transaction-id', ds_transaction_id) if ds_transaction_id
          doc.send('three-d-secure-reference-id', three_d_secure_reference_id) if three_d_secure_reference_id
          doc.send('three-d-secure-result-token', three_d_secure_result_token) if three_d_secure_result_token
        end
      end

      def add_level_3_data(doc, options)
        return unless options[:customer_reference_number]

        doc.send('level-3-data') do
          send_when_present(doc, :customer_reference_number, options)
          send_when_present(doc, :sales_tax_amount, options)
          send_when_present(doc, :freight_amount, options)
          send_when_present(doc, :duty_amount, options)
          send_when_present(doc, :destination_zip_code, options)
          send_when_present(doc, :destination_country_code, options)
          send_when_present(doc, :ship_from_zip_code, options)
          send_when_present(doc, :discount_amount, options)
          send_when_present(doc, :tax_amount, options)
          send_when_present(doc, :tax_rate, options)
          add_level_3_data_items(doc, options[:level_3_data_items]) if options[:level_3_data_items]
        end
      end

      def send_when_present(doc, options_key, options, xml_element_name = nil)
        return unless options[options_key]

        xml_element_name ||= options_key.to_s

        doc.send(xml_element_name.dasherize, options[options_key])
      end

      def add_level_3_data_items(doc, items)
        items.each do |item|
          doc.send('level-3-data-item') do
            item.each do |key, value|
              key = key.to_s.dasherize
              doc.send(key, value)
            end
          end
        end
      end

      def add_authorization(doc, authorization)
        doc.send('transaction-id', authorization)
      end

      def add_fraud_info(doc, options)
        doc.send('transaction-fraud-info') do
          doc.send('fraud-session-id', options[:fraud_session_id])
          doc.send('shopper-ip-address', options[:ip]) if options[:ip]
          doc.send('company', options[:company]) if options[:company]
          if options[:address_1]
            doc.send('shipping-contact-info') do
              doc.send('first-name', options[:first_name])
              doc.send('last-name', options[:last_name])
              doc.send('address1', options[:address1])
              doc.send('address2', options[:address2])
              doc.send('city', options[:city])
              doc.send('state', options[:state])
              doc.send('zip', options[:zip])
              doc.send('country', options[:country])
            end
          end
          doc.send('enterprise-site-id', options[:enterprise_site_id]) if options[:enterprise_site_id]
          doc.send('enterprise-udfs', options[:enterprise_udfs]) if options[:enterprise_udfs]
        end
      end

      def add_alt_transaction_purchase(doc, money, payment_method_details, options)
        doc.send('merchant-transaction-id', truncate(options[:order_id], 50)) if options[:order_id]
        doc.send('soft-descriptor', options[:soft_descriptor]) if options[:soft_descriptor]
        add_amount(doc, money, options)

        vaulted_shopper_id = payment_method_details.vaulted_shopper_id
        doc.send('vaulted-shopper-id', vaulted_shopper_id) if vaulted_shopper_id

        add_echeck_transaction(doc, payment_method_details.payment_method, options, vaulted_shopper_id.present?) if payment_method_details.check?

        add_fraud_info(doc, options)
        add_description(doc, options[:description])
      end

      def add_echeck_transaction(doc, check, options, vaulted_shopper)
        unless vaulted_shopper
          doc.send('payer-info') do
            add_personal_info(doc, check, options)
            add_echeck_company(doc, check)
          end
        end

        doc.send('ecp-transaction') do
          if vaulted_shopper
            doc.send('account-type', options[:account_type])
            doc.send('public-routing-number', options[:public_routing_number])
            doc.send('public-account-number', options[:public_account_number])
          else
            add_echeck(doc, check) unless vaulted_shopper
          end
        end

        doc.send('authorized-by-shopper', options[:authorized_by_shopper])
      end

      def add_echeck_company(doc, check)
        doc.send('company-name', truncate(check.name, 50)) if check.account_holder_type == 'business'
      end

      def add_echeck(doc, check)
        doc.send('account-number', check.account_number)
        doc.send('routing-number', check.routing_number)
        doc.send('account-type', BANK_ACCOUNT_TYPE_MAPPING["#{check.account_holder_type}_#{check.account_type}"])
      end

      def parse(response, action = nil)
        return bad_authentication_response if response.code.to_i == 401
        return forbidden_response(response.body) if response.code.to_i == 403
        if action == :get_payment_fields_token
          return { payment_fields_token: response.to_hash['location'].first.split('/').last }
        end
        return {} if response.body.blank?

        parsed = {}
        doc = Nokogiri::XML(response.body)
        doc.root.xpath('*').each do |node|
          if node.elements.empty?
            parsed[node.name.downcase] = node.text
          else
            node.elements.each do |childnode|
              parse_element(parsed, childnode)
            end
          end
        end

        parsed['content-location-header'] = response['content-location']
        parsed
      end

      def parse_element(parsed, node)
        if !node.elements.empty?
          node.elements.each { |e| parse_element(parsed, e) }
        else
          parsed[node.name.downcase] = node.text
        end
      end

      def api_request(action, request, verb, payment_method_details, options)
        ssl_request(verb, url(action, payment_method_details, options), request, headers)
      rescue ResponseError => e
        e.response
      end

      def commit(action, verb = :post, payment_method_details = PaymentMethodDetails.new(), options = {})
        if action == :refund
          options = yield
          request = nil
          resource_url = "#{payment_method_details.resource_url}/#{options[:authorization]}/refund?cancelsubscriptions=false"
          resource_url += "&amount=#{options[:money]}" if options[:money].present?
          payment_method_details = OpenStruct.new(resource_url: resource_url)
        elsif action != :get_payment_fields_token
          request = build_xml_request(action, payment_method_details) { |doc| yield(doc) }
        end

        response = api_request(action, request, verb, payment_method_details, options)

        parsed = parse(response, action)

        succeeded = success_from(action, response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          parsed,
          authorization: authorization_from(action, parsed, payment_method_details),
          avs_result: avs_result(parsed),
          cvv_result: cvv_result(parsed),
          error_code: error_code_from(parsed),
          test: test?
        )
      end

      def url(action = nil, payment_method_details = PaymentMethodDetails.new(), options = {})
        base = test? ? test_url : live_url
        resource = if [:store, :update, :retrieve].include?(action)
                     "vaulted-shoppers"
                   elsif action == :create_subscription
                     "recurring/ondemand"
                   elsif action == :charge_subscription
                     "recurring/ondemand/#{options[:subscription_id]}"
                   elsif action == :get_payment_fields_token
                     "payment-fields-tokens"
                   else
                     payment_method_details.resource_url
                   end
        if payment_method_details.vaulted_shopper_id && resource == "vaulted-shoppers"
          "#{base}/#{resource}" + "/#{payment_method_details.vaulted_shopper_id}"
        else
          "#{base}/#{resource}"
        end
      end

      def cvv_result(parsed)
        return if parsed.blank?
        CVVResult.new(CVC_CODE_TRANSLATOR[parsed['cvv-response-code']])
      end

      def avs_result(parsed)
        return if parsed.blank?
        AVSResult.new(code: AVS_CODE_TRANSLATOR[avs_lookup_key(parsed)])
      end

      def avs_lookup_key(p)
        "line1: #{p['avs-response-code-address']}, zip: #{p['avs-response-code-zip']}, name: #{p['avs-response-code-name']}"
      end

      def success_from(action, response)
        (200...300).cover?(response.code.to_i)
      end

      def message_from(succeeded, response)
        return 'Success' if succeeded

        parsed = parse(response)
        if parsed.dig('error-name') == 'FRAUD_DETECTED'
          fraud_codes_from(response)
        else
          parsed['description']
        end
      end

      def fraud_codes_from(response)
        event_summary = {}
        doc = Nokogiri::XML(response.body)
        fraud_events = doc.xpath('//xmlns:fraud-events', 'xmlns' => 'http://ws.plimus.com')
        fraud_events.children.each do |child|
          if child.children.children.any?
            event_summary[child.name] = event_summary[child.name] || []
            event = {}
            child.children.each do |chi|
              event[chi.name] = chi.text
            end
            event_summary[child.name] << event
          else
            event_summary[child.name] = child.text
          end
        end
        event_summary.to_json
      end

      def authorization_from(action, parsed_response, payment_method_details)
        return if action == :refund
        action == :store ? vaulted_shopper_id(parsed_response, payment_method_details) : parsed_response['transaction-id']
      end

      def vaulted_shopper_id(parsed_response, payment_method_details)
        return nil unless parsed_response['content-location-header']

        vaulted_shopper_id = parsed_response['content-location-header'].split('/').last
        vaulted_shopper_id += "|#{payment_method_details.payment_method_type}" if payment_method_details.alt_transaction?
        vaulted_shopper_id
      end

      def error_code_from(parsed_response)
        return if parsed_response.blank?
        parsed_response['code']
      end

      def root_attributes
        {
          xmlns: 'http://ws.plimus.com'
        }
      end

      def root_element(action, payment_method_details)
        if [:purchase, :authorize, :capture].include?(action)
          payment_method_details.root_element
        elsif [:create_subscription, :charge_subscription].include?(action)
          "charge"
        else
          'vaulted-shopper'
        end
      end

      def headers
        {
          'Content-Type' => 'application/xml',
          'bluesnap-version' => API_VERSION,
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:api_username]}:#{@options[:api_password]}").strip),
        }
      end

      def build_xml_request(action, payment_method_details)
        builder = Nokogiri::XML::Builder.new
        builder.__send__(root_element(action, payment_method_details), root_attributes) do |doc|
          if action == :store
            doc.send('card-transaction-type', TRANSACTIONS[action]) if TRANSACTIONS[action] && !payment_method_details.alt_transaction?
          end
          yield(doc)
        end
        builder.doc.root.to_xml
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300
          response
        else
          raise ResponseError.new(response)
        end
      end

      def bad_authentication_response
        { 'description' => 'Unable to authenticate.  Please check your credentials.' }
      end

      def forbidden_response(body)
        { 'description' => body }
      end
    end

    class PaymentMethodDetails
      attr_reader :payment_method, :payment_method_type
      attr_accessor :vaulted_shopper_id

      def initialize(payment_method = nil)
        @payment_method = payment_method
        @payment_method_type = nil
        parse(payment_method)
      end

      def check?
        @payment_method.is_a?(Check) || @payment_method_type == 'check'
      end

      def card?
        @payment_method.is_a?(CreditCard) || @payment_method_type == 'credit_card'
      end

      def alt_transaction?
        check?
      end

      def card_transaction?
        card?
      end

      def root_element
        alt_transaction? ? 'alt-transaction' : 'card-transaction'
      end

      def resource_url
        alt_transaction? ? 'alt-transactions' : 'transactions'
      end

      private

      def parse(payment_method)
        return unless payment_method

        if payment_method.is_a?(String)
          @vaulted_shopper_id, payment_method_type = payment_method.split('|')
          @payment_method_type = payment_method_type if payment_method_type.present?
        elsif payment_method.is_a?(Check)
          @payment_method_type = payment_method.type
        else
          @payment_method_type = 'credit_card'
        end
      end
    end
  end
end
