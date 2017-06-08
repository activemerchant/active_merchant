require 'nokogiri'

module ActiveMerchant
  module Billing
    class BlueSnapGateway < Gateway
      self.test_url = "https://sandbox.bluesnap.com/services/2"
      self.live_url = "https://ws.bluesnap.com/services/2"
      self.supported_countries = %w(US CA GB AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE)

      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club, :maestro]

      self.homepage_url = 'https://home.bluesnap.com/'
      self.display_name = 'BlueSnap'

      TRANSACTIONS = {
        purchase: "AUTH_CAPTURE",
        authorize: "AUTH_ONLY",
        capture: "CAPTURE",
        void: "AUTH_REVERSAL",
        refund: "REFUND"
      }.freeze

      ACH_ACCOUNT_TYPES = {
        personal_checking: "CONSUMER_CHECKING",
        personal_savings: "CONSUMER_SAVINGS",
        business_checking: "CORPORATE_CHECKING",
        business_savings: "CORPORATE_SAVINGS"
      }.freeze

      CVC_CODE_TRANSLATOR = {
        'MA' => 'M',
        'NC' => 'U',
        'ND' => 'P',
        'NM' => 'N',
        'NP' => 'S'
      }.freeze

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
      }.freeze

      def initialize(options={})
        requires!(options, :api_username, :api_password)
        super
      end

      def purchase(money, payment_method, options = {})
        payment_type = payment_method.is_a?(Check) ? :check : :credit_card
        commit(:purchase, :post, payment_type) do |doc|
          add_auth_purchase(doc, money, payment_method, options)
        end
      end

      def authorize(money, payment_method, options = {})
        commit(:authorize) do |doc|
          add_auth_purchase(doc, money, payment_method, options)
        end
      end

      def capture(money, authorization, options = {})
        commit(:capture, :put) do |doc|
          add_authorization(doc, authorization)
          add_order(doc, options)
        end
      end

      def refund(money, authorization, options = {})
        commit(:refund, :put) do |doc|
          add_authorization(doc, authorization)
          add_amount(doc, money)
          add_order(doc, options)
        end
      end

      def void(authorization, payment_method, options = {})
        payment_type = payment_method.is_a?(Check) ? :check : :credit_card
        commit(:void, :put, payment_type) do |doc|
          add_authorization(doc, authorization)
          add_order(doc, options)
        end
      end

      def verify(payment_method, options = {})
        authorize(0, payment_method, options)
      end

      def store(credit_card, options = {})
        commit(:store) do |doc|
          add_personal_info(doc, credit_card, options)
          doc.send("payment-sources") do
            doc.send("credit-card-info") do
              add_credit_card(doc, credit_card)
            end
          end
          add_order(doc, options)
        end
      end

      def verify_credentials
        begin
          ssl_get("#{url}/nonexistent", headers)
        rescue ResponseError => e
          return false if e.response.code.to_i == 401
        end

        true
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]')
                  .gsub(%r((<card-number>).+(</card-number>)), '\1[FILTERED]\2')
                  .gsub(%r((<security-code>).+(</security-code>)), '\1[FILTERED]\2')
                  .gsub(%r((<account-number>).+(</account-number>)), '\1[FILTERED]\2')
                  .gsub(%r((<routing-number>).+(</routing-number>)), '\1[FILTERED]\2')
                  .gsub(%r((<routing-number>).+(</routing-number>)), '\1[FILTERED]\2')
                  .gsub(%r((<encrypted-card-number>).+(</encrypted-card-number>)), '\1[FILTERED]\2')
                  .gsub(%r((<encrypted-security-code>).+(</encrypted-security-code>)), '\1[FILTERED]\2')
      end

      private

      def add_auth_purchase(doc, money, payment_method, options)
        doc.send("recurring-transaction", options[:recurring] ? "RECURRING" : "ECOMMERCE")
        add_order(doc, options)
        add_amount(doc, money)
        add_fraud_info(doc, options)

        doc.send("vaulted-shopper-id", payment_method) if payment_method.is_a? String
        add_card_holder_info(doc, payment_method, options) if payment_method.is_a? CreditCard
        add_payer_info(doc, payment_method, options) if payment_method.is_a? Check
      end

      def add_payer_info(doc, payment_method, options)
        doc.send("payer-info") do
          add_personal_info(doc, payment_method, options)
        end
        add_ach_info(doc, payment_method)
      end

      def add_card_holder_info(doc, payment_method, options)
        doc.send("card-holder-info") do
          add_personal_info(doc, payment_method, options)
        end
        add_credit_card(doc, payment_method, options)
      end

      def add_fraud_info(doc, options)
        doc.send("transaction-fraud-info") do
          doc.send("shopper-ip-address", options[:ip]) if options[:ip]
        end
      end

      def add_amount(doc, money)
        doc.amount(amount(money))
        doc.currency(options[:currency] || currency(money))
      end

      def add_personal_info(doc, card_or_ach, options)
        doc.send("first-name", card_or_ach.first_name)
        doc.send("last-name", card_or_ach.last_name)
        add_company_name(doc, card_or_ach) if card_or_ach.is_a? Check
        doc.email(options[:email]) if options[:email]
        doc.send("phone", options[:billing_address][:phone]) if options[:billing_address]
        add_address(doc, options)
      end

      def add_company_name(doc, check)
        return unless check.account_holder_type == 'business'
        doc.send("company-name", check.name)
      end

      def add_account_type(doc, check)
        type_key = [
          check.account_holder_type,
          check.account_type
        ].join('_').to_sym
        doc.send("account-type", ACH_ACCOUNT_TYPES[type_key])
      end

      def add_ach_info(doc, check)
        doc.send("ecp-transaction") do
          doc.send("account-number", check.account_number)
          doc.send("routing-number", check.routing_number)
          add_account_type(doc, check)
        end
        # TODO: Be sure to add form field for this and pull the value from it.
        doc.send("authorized-by-shopper", "true")
      end

      def add_credit_card(doc, card, options = nil)
        doc.send("credit-card") do
          if options && options[:encrypted]
            add_encrypted_fields(doc, card, options)
          else
            doc.send("card-number", card.number)
            doc.send("security-code", card.verification_value)
          end
          doc.send("expiration-month", card.month)
          doc.send("expiration-year", card.year)
        end
      end

      def add_encrypted_fields(doc, card, options)
        doc.send("encrypted-card-number", options[:encrypted_cc])
        doc.send("encrypted-security-code", options[:encrypted_cvv])
      end

      def add_description(doc, description)
        doc.send("transaction-meta-data") do
          doc.send("meta-data") do
            doc.send("meta-key", "description")
            doc.send("meta-value", truncate(description, 50))
            doc.send("meta-description", "Description")
          end
        end
      end

      def add_order(doc, options)
        doc.send("merchant-transaction-id", truncate(options[:order_id], 50)) if options[:order_id]
        doc.send("soft-descriptor", options[:soft_descriptor]) if options[:soft_descriptor]
        add_description(doc, options[:description]) if options[:description]
      end

      def add_address(doc, options)
        address = options[:billing_address]
        return unless address

        doc.country(address[:country]) if address[:country]
        doc.state(address[:state]) if address[:state]
        doc.address(address[:address]) if address[:address]
        doc.city(address[:city]) if address[:city]
        doc.zip(address[:zip]) if address[:zip]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_authorization(doc, authorization)
        doc.send("transaction-id", authorization)
      end

      def add_transaction_type(doc, authorization)
        doc.send("")
      end

      def parse(response)
        return bad_authentication_response if response.code.to_i == 401

        parsed = {}
        doc = Nokogiri::XML(response.body)
        doc.root.xpath('*').each do |node|
          if (node.elements.empty?)
            parsed[node.name.downcase] = node.text
          else
            node.elements.each do |childnode|
              parse_element(parsed, childnode)
            end
          end
        end

        parsed["content-location-header"] = response['content-location']
        parsed
      end

      def parse_element(parsed, node)
        if !node.elements.empty?
          node.elements.each { |e| parse_element(parsed, e) }
        else
          parsed[node.name.downcase] = node.text
        end
      end

      def api_request(action, request, verb, type = nil)
        ssl_request(verb, url(action, type), request, headers)
      rescue ResponseError => e
        e.response
      end

      def build_response(succeeded, action, parsed)
        Response.new(
          succeeded,
          message_from(succeeded, parsed),
          parsed,
          authorization: authorization_from(action, parsed),
          avs_result: avs_result(parsed),
          cvv_result: cvv_result(parsed),
          error_code: error_code_from(parsed),
          test: test?
        )
      end

      def commit(action, verb = :post, payment_type = nil)
        request = build_xml_request(action, payment_type) { |doc| yield(doc) }
        response = api_request(action, request, verb, payment_type)
        parsed = parse(response)
        succeeded = success_from(action, response)
        build_response(succeeded, action, parsed)
      end

      def url(action = nil, payment_type = nil)
        base = test? ? test_url : live_url
        resource = if action == :store
                     "vaulted-shoppers"
                   elsif payment_type && payment_type == :check
                     "alt-transactions"
                   else
                     "transactions"
                   end
        "#{base}/#{resource}"
      end

      def cvv_result(parsed)
        CVVResult.new(CVC_CODE_TRANSLATOR[parsed["cvv-response-code"]])
      end

      def avs_result(parsed)
        AVSResult.new(code: AVS_CODE_TRANSLATOR[avs_lookup_key(parsed)])
      end

      def avs_lookup_key(p)
        "line1: #{p['avs-response-code-address']}, zip: #{p['avs-response-code-zip']}, name: #{p['avs-response-code-name']}"
      end

      def success_from(action, response)
        (200...300).include?(response.code.to_i)
      end

      def message_from(succeeded, parsed_response)
        return "Success" if succeeded
        parsed_response["description"]
      end

      def authorization_from(action, parsed_response)
        (action == :store) ? vaulted_shopper_id(parsed_response) : parsed_response["transaction-id"]
      end

      def vaulted_shopper_id(parsed_response)
        return nil unless parsed_response["content-location-header"]
        parsed_response["content-location-header"].split("/").last
      end

      def error_code_from(parsed_response)
        parsed_response["code"]
      end

      def root_attributes
        {
          xmlns: "http://ws.plimus.com"
        }
      end

      def root_element(action, payment_type = nil)
        if action == :store
          "vaulted-shopper"
        elsif payment_type && payment_type == :check
          "alt-transaction"
        else
          "card-transaction"
        end
      end

      def headers
        {
          'Content-Type' => 'application/xml',
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:api_username]}:#{@options[:api_password]}").strip),
        }
      end

      def build_xml_request(action, payment_type = nil)
        builder = Nokogiri::XML::Builder.new
        builder.__send__(root_element(action, payment_type), root_attributes) do |doc|
          if payment_type == :credit_card
            doc.send("card-transaction-type", TRANSACTIONS[action]) if TRANSACTIONS[action]
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
          raise ResponseError, response
        end
      end

      def bad_authentication_response
        {"description" => "Unable to authenticate.  Please check your credentials."}
      end
    end
  end
end
