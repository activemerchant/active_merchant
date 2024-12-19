require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Public: This gateway allows you to interact with any gateway you've
    # created in Spreedly (https://spreedly.com).  It's an adapter which can be
    # particularly useful if you already have code interacting with
    # ActiveMerchant and want to easily take advantage of Spreedly's vault.
    class SpreedlyCoreGateway < Gateway
      SUCCESS_CODE = 200
      SOFT_DECLINE_CODES = [401, 402, 408, 415, 422].freeze

      self.live_url = 'https://core.spreedly.com/v1'

      self.supported_countries = %w(AD AE AT AU BD BE BG BN CA CH CY CZ DE DK EE EG ES FI FR GB
                                    GI GR HK HU ID IE IL IM IN IS IT JO KW LB LI LK LT LU LV MC
                                    MT MU MV MX MY NL NO NZ OM PH PL PT QA RO SA SE SG SI SK SM
                                    TR TT UM US VA VN ZA)

      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'https://spreedly.com'
      self.display_name = 'Spreedly'
      self.money_format = :cents
      self.default_currency = 'USD'

      # Public: Create a new Spreedly gateway.
      #
      # options - A hash of options:
      #           :login         - The environment key.
      #           :password      - The access secret.
      #           :gateway_token - The token of the gateway you've created in
      #                            Spreedly.
      def initialize(options = {})
        requires!(options, :login, :password, :gateway_token)
        super
      end

      # Public: Run a purchase transaction.
      #
      # money          - The monetary amount of the transaction in cents.
      # payment_method - The CreditCard or Check or the Spreedly payment method token.
      # options        - A hash of options:
      #                  :store - Retain the payment method if the purchase
      #                           succeeds.  Defaults to false.  (optional)
      def purchase(money, payment_method, options = {})
        request = build_transaction_request(money, payment_method, options)
        commit("gateways/#{options[:gateway_token] || @options[:gateway_token]}/purchase.xml", request)
      end

      # Public: Run an authorize transaction.
      #
      # money          - The monetary amount of the transaction in cents.
      # payment_method - The CreditCard or the Spreedly payment method token.
      # options        - A hash of options:
      #                  :store - Retain the payment method if the authorize
      #                           succeeds.  Defaults to false.  (optional)
      def authorize(money, payment_method, options = {})
        request = build_transaction_request(money, payment_method, options)
        commit("gateways/#{@options[:gateway_token]}/authorize.xml", request)
      end

      def capture(money, authorization, options = {})
        request = build_xml_request('transaction') do |doc|
          add_invoice(doc, money, options)
        end

        commit("transactions/#{authorization}/capture.xml", request)
      end

      def refund(money, authorization, options = {})
        request = build_xml_request('transaction') do |doc|
          add_invoice(doc, money, options)
          add_extra_options(:gateway_specific_fields, doc, options)
        end

        commit("transactions/#{authorization}/credit.xml", request)
      end

      def void(authorization, options = {})
        commit("transactions/#{authorization}/void.xml", '')
      end

      # Public: Determine whether a credit card is chargeable card and available for purchases.
      #
      # payment_method - The CreditCard or the Spreedly payment method token.
      # options        - A hash of options:
      #                  :store - Retain the payment method if the verify
      #                           succeeds.  Defaults to false.  (optional)
      def verify(payment_method, options = {})
        if payment_method.is_a?(String)
          verify_with_token(payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { save_card(options[:store], payment_method, options) }
            r.process { verify_with_token(r.authorization, options) }
          end
        end
      end

      # Public: Store a credit card in the Spreedly vault and retain it.
      #
      # credit_card    - The CreditCard to store
      # options        - A standard ActiveMerchant options hash
      def store(credit_card, options = {})
        retain = true
        save_card(retain, credit_card, options)
      end

      # Public: Redact the CreditCard in Spreedly. This wipes the sensitive
      #         payment information from the card.
      #
      # credit_card    - The CreditCard to store
      # options        - A standard ActiveMerchant options hash
      def unstore(authorization, options = {})
        commit("payment_methods/#{authorization}/redact.xml", '', :put)
      end

      # Public: Get the transaction with the given token.
      def find(transaction_token)
        commit("transactions/#{transaction_token}.xml", nil, :get)
      end

      alias status find

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<number>).+(</number>)), '\1[FILTERED]\2').
          gsub(%r((<verification_value>).+(</verification_value>)), '\1[FILTERED]\2').
          gsub(%r((<payment_method_token>).+(</payment_method_token>)), '\1[FILTERED]\2')
      end

      private

      def save_card(retain, credit_card, options)
        request = build_xml_request('payment_method') do |doc|
          add_credit_card(doc, credit_card, options)
          add_extra_options(:data, doc, options)
          doc.retained(true) if retain
        end

        commit('payment_methods.xml', request, :post, :payment_method_token)
      end

      def purchase_with_token(money, payment_method_token, options)
        request = build_transaction_request(money, payment_method_token, options)
        commit("gateways/#{options[:gateway_token] || @options[:gateway_token]}/purchase.xml", request)
      end

      def authorize_with_token(money, payment_method_token, options)
        request = build_transaction_request(money, payment_method_token, options)
        commit("gateways/#{@options[:gateway_token]}/authorize.xml", request)
      end

      def verify_with_token(payment_method_token, options)
        request = build_transaction_request(nil, payment_method_token, options)
        commit("gateways/#{@options[:gateway_token]}/verify.xml", request)
      end

      def build_transaction_request(money, payment_method, options)
        build_xml_request('transaction') do |doc|
          add_invoice(doc, money, options)
          add_payment_method(doc, payment_method, options)
          add_extra_options(:gateway_specific_fields, doc, options)
        end
      end

      def add_invoice(doc, money, options)
        doc.amount amount(money) unless money.nil?
        doc.currency_code(options[:currency] || currency(money) || default_currency)
        doc.order_id(options[:order_id])
        doc.ip(options[:ip]) if options[:ip]
        doc.description(options[:description]) if options[:description]

        doc.merchant_name_descriptor(options[:merchant_name_descriptor]) if options[:merchant_name_descriptor]
        doc.merchant_location_descriptor(options[:merchant_location_descriptor]) if options[:merchant_location_descriptor]
      end

      def add_payment_method(doc, payment_method, options)
        doc.retain_on_success(true) if options[:store]

        if payment_method.is_a?(String)
          doc.payment_method_token(payment_method)
        elsif payment_method.is_a?(CreditCard)
          add_credit_card(doc, payment_method, options)
        elsif payment_method.is_a?(Check)
          add_bank_account(doc, payment_method, options)
        end
      end

      def add_credit_card(doc, credit_card, options)
        doc.credit_card do
          doc.number(credit_card.number)
          doc.verification_value(credit_card.verification_value)
          doc.first_name(credit_card.first_name)
          doc.last_name(credit_card.last_name)
          doc.month(credit_card.month)
          doc.year(format(credit_card.year, :four_digits_year))
          doc.email(options[:email])
          doc.address1(options[:billing_address].try(:[], :address1))
          doc.address2(options[:billing_address].try(:[], :address2))
          doc.city(options[:billing_address].try(:[], :city))
          doc.state(options[:billing_address].try(:[], :state))
          doc.zip(options[:billing_address].try(:[], :zip))
          doc.country(options[:billing_address].try(:[], :country))
          doc.phone_number(options[:billing_address].try(:[], :phone))
          doc.shipping_address1(options[:shiping_address].try(:[], :address1))
          doc.shipping_address2(options[:shiping_address].try(:[], :address2))
          doc.shipping_city(options[:shiping_address].try(:[], :city))
          doc.shipping_state(options[:shiping_address].try(:[], :state))
          doc.shipping_zip(options[:shiping_address].try(:[], :zip))
          doc.shipping_country(options[:shiping_address].try(:[], :country))
          doc.shipping_phone_number(options[:shiping_address].try(:[], :phone))
        end
      end

      def add_bank_account(doc, bank_account, options)
        doc.bank_account do
          doc.first_name(bank_account.first_name)
          doc.last_name(bank_account.last_name)
          doc.bank_routing_number(bank_account.routing_number)
          doc.bank_account_number(bank_account.account_number)
          doc.bank_account_type(bank_account.account_type)
          doc.bank_account_holder_type(bank_account.account_holder_type)
        end
      end

      def add_extra_options(type, doc, options)
        doc.send(type) do
          extra_options_to_doc(doc, options[type])
        end
      end

      def extra_options_to_doc(doc, value)
        return doc.text value unless value.kind_of? Hash

        value.each do |k, v|
          doc.send(k) do
            extra_options_to_doc(doc, v)
          end
        end
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath('*').each do |node|
          if node.elements.empty?
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              childnode_to_response(response, node, childnode)
            end
          end
        end

        response
      end

      def childnode_to_response(response, node, childnode)
        node_name = node.name.downcase
        childnode_name = childnode.name.downcase
        composed_name = "#{node_name}_#{childnode_name}"

        childnodes_present = !childnode.elements.empty?

        if childnodes_present && composed_name == 'payment_method_data'
          response[composed_name.to_sym] = Hash.from_xml(childnode.to_s).values.first
        elsif childnodes_present && node_name == 'gateway_specific_response_fields'
          response[node_name.to_sym] = {
            childnode_name => Hash.from_xml(childnode.to_s).values.first
          }
        else
          response[composed_name.to_sym] = childnode.text
        end
      end

      def build_xml_request(root)
        builder = Nokogiri::XML::Builder.new
        builder.__send__(root) do |doc|
          yield(doc)
        end
        builder.to_xml
      end

      def commit(relative_url, request, method = :post, authorization_field = :token)
        begin
          raw_response = ssl_request(method, request_url(relative_url), request, headers)
        rescue ResponseError => e
          raw_response = e.response.body
        end

        response_from(raw_response, authorization_field, request, relative_url)
      end

      def response_from(raw_response, authorization_field, request_body, relative_url)
        parsed = parse(raw_response)
        options = {
          authorization: parsed[authorization_field],
          test: (parsed[:on_test_gateway] == 'true'),
          avs_result: { code: parsed[:response_avs_code] },
          cvv_result: parsed[:response_cvv_code],
          response_type: response_type(@response_http_code.to_i),
          response_http_code: @response_http_code,
          request_endpoint: request_url(relative_url),
          request_method: :post,
          request_body:
        }

        Response.new(parsed[:succeeded] == 'true', parsed[:message] || parsed[:error], parsed, options)
      end

      def headers
        {
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:login]}:#{@options[:password]}").chomp),
          'Content-Type' => 'text/xml'
        }
      end

      def request_url(relative_url)
        "#{live_url}/#{relative_url}"
      end

      def handle_response(response)
        @response_http_code = response.code.to_i
        case @response_http_code
        when 200...300
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def response_type(code)
        if code == SUCCESS_CODE
          0
        elsif SOFT_DECLINE_CODES.include?(code)
          1
        else
          2
        end
      end
    end
  end
end
