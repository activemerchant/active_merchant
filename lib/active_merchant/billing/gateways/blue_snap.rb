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

      def initialize(options={})
        requires!(options, :api_username, :api_password)
        super
      end

      def purchase(money, payment_method, options={})
        commit(:purchase) do |doc|
          add_auth_purchase(doc, money, payment_method, options)
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
        end
      end

      def refund(money, authorization, options={})
        commit(:refund, :put) do |doc|
          add_authorization(doc, authorization)
          add_amount(doc, money)
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
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<card-number>).+(</card-number>)), '\1[FILTERED]\2').
          gsub(%r((<security-code>).+(</security-code>)), '\1[FILTERED]\2')
      end

      private

      def add_auth_purchase(doc, money, payment_method, options)
        doc.send("recurring-transaction", options[:recurring] ? "RECURRING" : "ECOMMERCE")
        add_order(doc, options)
        add_amount(doc, money)
        doc.send("transaction-fraud-info") do
          doc.send("shopper-ip-address", options[:ip]) if options[:ip]
        end

        if payment_method.is_a?(String)
          doc.send("vaulted-shopper-id", payment_method)
        else
          doc.send("card-holder-info") do
            add_personal_info(doc, payment_method, options)
          end
          add_credit_card(doc, payment_method)
        end
      end

      def add_amount(doc, money)
        doc.amount(amount(money))
        doc.currency(options[:currency] || currency(money))
      end

      def add_personal_info(doc, credit_card, options)
        doc.send("first-name", credit_card.first_name)
        doc.send("last-name", credit_card.last_name)
        doc.email(options[:email]) if options[:email]
        add_address(doc, options)
      end

      def add_credit_card(doc, card)
        doc.send("credit-card") do
          doc.send("card-number", card.number)
          doc.send("security-code", card.verification_value)
          doc.send("expiration-month", card.month)
          doc.send("expiration-year", card.year)
        end
      end

      def add_description(doc, description)
        doc.send("transaction-meta-data") do
          doc.send("meta-data") do
            doc.send("meta-key", "description")
            doc.send("meta-value", truncate(description, 500))
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
          node.elements.each {|e| parse_element(parsed, e) }
        else
          parsed[node.name.downcase] = node.text
        end
      end

      def api_request(action, request, verb)
        begin
          ssl_request(verb, url(action), request, headers)
        rescue ResponseError => e
          e.response
        end
      end

      def commit(action, verb = :post)
        request = build_xml_request(action) { |doc| yield(doc) }
        response = api_request(action, request, verb)
        parsed = parse(response)

        succeeded = success_from(action, response)
        Response.new(
          succeeded,
          message_from(succeeded, parsed),
          parsed,
          authorization: authorization_from(action, parsed),
          avs_result: avs_result(parsed),
          cvv_result: cvv_result(parsed),
          error_code: error_code_from(parsed),
          test: test?,
        )
      end

      def url(action = nil)
        base = test? ? test_url : live_url
        resource = (action == :store) ? "vaulted-shoppers" : "transactions"
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

      def root_element(action)
        (action == :store) ? "vaulted-shopper" : "card-transaction"
      end

      def headers
        {
          'Content-Type' => 'application/xml',
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:api_username]}:#{@options[:api_password]}").strip),
        }
      end

      def build_xml_request(action)
        builder = Nokogiri::XML::Builder.new
        builder.__send__(root_element(action), root_attributes) do |doc|
          doc.send("card-transaction-type", TRANSACTIONS[action]) if TRANSACTIONS[action]
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
        { "description" => "Unable to authenticate.  Please check your credentials." }
      end
    end
  end
end
