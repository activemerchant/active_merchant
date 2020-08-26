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
      self.currencies_with_three_decimal_places = %w(BHD JOD KWD OMR TND)

      self.homepage_url = 'https://home.bluesnap.com/'
      self.display_name = 'BlueSnap'

      TRANSACTIONS = {
        purchase: 'AUTH_CAPTURE',
        authorize: 'AUTH_ONLY',
        capture: 'CAPTURE',
        void: 'AUTH_REVERSAL',
        refund: 'REFUND'
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
        'line1: N, zip: N, name: N' => 'N'
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

        commit(:purchase, :post, payment_method_details) do |doc|
          if payment_method_details.alt_transaction?
            add_alt_transaction_purchase(doc, money, payment_method_details, options)
          else
            add_auth_purchase(doc, money, payment_method, options)
          end
        end
      end

      def authorize(money, payment_method, options={})
        commit(:authorize) do |doc|
          add_auth_purchase(doc, money, payment_method, options)
        end
      end

      def capture(money, authorization, options={})
        commit(:capture, :put) do |doc|
          add_authorization(doc, authorization)
          add_order(doc, options)
          add_amount(doc, money, options) if options[:include_capture_amount] == true
        end
      end

      def refund(money, authorization, options={})
        commit(:refund, :put) do |doc|
          add_authorization(doc, authorization)
          add_amount(doc, money, options)
          add_order(doc, options)
        end
      end

      def void(authorization, options={})
        commit(:void, :put) do |doc|
          add_authorization(doc, authorization)
          add_order(doc, options)
        end
      end

      def verify(payment_method, options={})
        authorize(0, payment_method, options)
      end

      def store(payment_method, options = {})
        payment_method_details = PaymentMethodDetails.new(payment_method)

        commit(:store, :post, payment_method_details) do |doc|
          add_personal_info(doc, payment_method, options)
          add_echeck_company(doc, payment_method) if payment_method_details.check?
          doc.send('payment-sources') do
            payment_method_details.check? ? store_echeck(doc, payment_method) : store_credit_card(doc, payment_method)
          end
          add_order(doc, options)
        end
      end

      def store_credit_card(doc, payment_method)
        doc.send('credit-card-info') do
          add_credit_card(doc, payment_method)
        end
      end

      def store_echeck(doc, payment_method)
        doc.send('ecp-info') do
          doc.send('ecp') do
            add_echeck(doc, payment_method)
          end
        end
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

      def add_auth_purchase(doc, money, payment_method, options)
        doc.send('recurring-transaction', options[:recurring] ? 'RECURRING' : 'ECOMMERCE')
        add_order(doc, options)
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

      def add_metadata(doc, options)
        transaction_meta_data = options.fetch(:transaction_meta_data, {})
        return if transaction_meta_data.empty? && !options[:description]

        doc.send('transaction-meta-data') do
          # ensure backwards compatibility for calls expecting :description
          # to become meta-data fields.
          if options[:description]
            doc.send('meta-data') do
              doc.send('meta-key', 'description')
              doc.send('meta-value', truncate(options[:description], 500))
              doc.send('meta-description', 'Description')
            end
          end

          # https://developers.bluesnap.com/v8976-XML/docs/meta-data
          transaction_meta_data.each do |entry|
            doc.send('meta-data') do
              doc.send('meta-key', truncate(entry[:meta_key], 40))
              doc.send('meta-value', truncate(entry[:meta_value], 500))
              doc.send('meta-description', truncate(entry[:meta_description], 40))
            end
          end
        end
      end

      def add_order(doc, options)
        doc.send('merchant-transaction-id', truncate(options[:order_id], 50)) if options[:order_id]
        doc.send('soft-descriptor', options[:soft_descriptor]) if options[:soft_descriptor]
        add_metadata(doc, options)
        add_3ds(doc, options[:three_d_secure]) if options[:three_d_secure]
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
        eci = three_d_secure_options[:eci]
        cavv = three_d_secure_options[:cavv]
        xid = three_d_secure_options[:xid]
        ds_transaction_id = three_d_secure_options[:ds_transaction_id]
        version = three_d_secure_options[:version]

        doc.send('three-d-secure') do
          doc.eci(eci) if eci
          doc.cavv(cavv) if cavv
          doc.xid(xid) if xid
          doc.send('three-d-secure-version', version) if version
          doc.send('ds-transaction-id', ds_transaction_id) if ds_transaction_id
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
          doc.send('shopper-ip-address', options[:ip]) if options[:ip]
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
        add_metadata(doc, options)
      end

      def add_echeck_transaction(doc, check, options, vaulted_shopper)
        unless vaulted_shopper
          doc.send('payer-info') do
            add_personal_info(doc, check, options)
            add_echeck_company(doc, check)
          end
        end

        doc.send('ecp-transaction') do
          add_echeck(doc, check) unless vaulted_shopper
        end

        doc.send('authorized-by-shopper', options[:authorized_by_shopper])
      end

      def add_echeck_company(doc, check)
        doc.send('company-name', truncate(check.name, 50)) if check.account_holder_type = 'business'
      end

      def add_echeck(doc, check)
        doc.send('account-number', check.account_number)
        doc.send('routing-number', check.routing_number)
        doc.send('account-type', BANK_ACCOUNT_TYPE_MAPPING["#{check.account_holder_type}_#{check.account_type}"])
      end

      def parse(response)
        return bad_authentication_response if response.code.to_i == 401
        return forbidden_response(response.body) if response.code.to_i == 403

        parsed = {}
        doc = Nokogiri::XML(response.body)
        doc.root.xpath('*').each do |node|
          name = node.name.downcase

          if node.elements.empty?
            parsed[name] = node.text
          elsif name == 'transaction-meta-data'
            metadata = []
            node.elements.each { |m|
              metadata.push parse_metadata_entry(m)
            }

            parsed['transaction-meta-data'] = metadata
          else
            node.elements.each { |childnode|
              parse_element(parsed, childnode)
            }
          end
        end

        parsed['content-location-header'] = response['content-location']
        parsed
      end

      def parse_metadata_entry(node)
        entry = {}

        node.elements.each { |e|
          entry = entry.merge({
            e.name => e.text
          })
        }

        entry
      end

      def parse_element(parsed, node)
        if !node.elements.empty?
          node.elements.each { |e| parse_element(parsed, e) }
        else
          parsed[node.name.downcase] = node.text
        end
      end

      def api_request(action, request, verb, payment_method_details)
        ssl_request(verb, url(action, payment_method_details), request, headers)
      rescue ResponseError => e
        e.response
      end

      def commit(action, verb = :post, payment_method_details = PaymentMethodDetails.new())
        request = build_xml_request(action, payment_method_details) { |doc| yield(doc) }
        response = api_request(action, request, verb, payment_method_details)
        parsed = parse(response)

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

      def url(action = nil, payment_method_details = PaymentMethodDetails.new())
        base = test? ? test_url : live_url
        resource = action == :store ? 'vaulted-shoppers' : payment_method_details.resource_url
        "#{base}/#{resource}"
      end

      def cvv_result(parsed)
        CVVResult.new(CVC_CODE_TRANSLATOR[parsed['cvv-response-code']])
      end

      def avs_result(parsed)
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
        action == :store ? vaulted_shopper_id(parsed_response, payment_method_details) : parsed_response['transaction-id']
      end

      def vaulted_shopper_id(parsed_response, payment_method_details)
        return nil unless parsed_response['content-location-header']

        vaulted_shopper_id = parsed_response['content-location-header'].split('/').last
        vaulted_shopper_id += "|#{payment_method_details.payment_method_type}" if payment_method_details.alt_transaction?
        vaulted_shopper_id
      end

      def error_code_from(parsed_response)
        parsed_response['code']
      end

      def root_attributes
        {
          xmlns: 'http://ws.plimus.com'
        }
      end

      def root_element(action, payment_method_details)
        action == :store ? 'vaulted-shopper' : payment_method_details.root_element
      end

      def headers
        {
          'Content-Type' => 'application/xml',
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:api_username]}:#{@options[:api_password]}").strip)
        }
      end

      def build_xml_request(action, payment_method_details)
        builder = Nokogiri::XML::Builder.new
        builder.__send__(root_element(action, payment_method_details), root_attributes) do |doc|
          doc.send('card-transaction-type', TRANSACTIONS[action]) if TRANSACTIONS[action] && !payment_method_details.alt_transaction?
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
      attr_reader :payment_method, :vaulted_shopper_id, :payment_method_type

      def initialize(payment_method = nil)
        @payment_method = payment_method
        @payment_method_type = nil
        parse(payment_method)
      end

      def check?
        @payment_method.is_a?(Check) || @payment_method_type == 'check'
      end

      def alt_transaction?
        check?
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
