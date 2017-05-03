require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IveriGateway < Gateway
      self.live_url = self.test_url = 'https://portal.nedsecure.co.za/iVeriWebService/Service.asmx'

      self.supported_countries = ['US', 'ZA', 'GB']
      self.default_currency = 'ZAR'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'http://www.iveri.com'
      self.display_name = 'iVeri'

      def initialize(options={})
        requires!(options, :app_id, :cert_id)
        super
      end

      def purchase(money, payment_method, options={})
        post = build_vxml_request('Debit', options) do |xml|
          add_auth_purchase_params(xml, money, payment_method, options)
        end

        commit(post)
      end

      def authorize(money, payment_method, options={})
        post = build_vxml_request('Authorisation', options) do |xml|
          add_auth_purchase_params(xml, money, payment_method, options)
        end

        commit(post)
      end

      def capture(money, authorization, options={})
        post = build_vxml_request('Debit', options) do |xml|
          add_authorization(xml, authorization, options)
        end

        commit(post)
      end

      def refund(money, authorization, options={})
        post = build_vxml_request('Credit', options) do |xml|
          add_amount(xml, money, options)
          add_authorization(xml, authorization, options)
        end

        commit(post)
      end

      def void(authorization, options={})
        post = build_vxml_request('Void', options) do |xml|
          add_authorization(xml, authorization, options)
        end

        commit(post)
      end

      def verify(credit_card, options={})
        authorize(0, credit_card, options)
      end

      def verify_credentials
        void = void('', options)
        return true if void.message ==  'Missing OriginalMerchantTrace'
        false
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((CertificateID=\\\")[^\\]*), '\1[FILTERED]').
          gsub(%r((&lt;PAN&gt;)[^&]*), '\1[FILTERED]').
          gsub(%r((&lt;CardSecurityCode&gt;)[^&]*), '\1[FILTERED]')
      end

      private

      def build_xml_envelope(vxml)
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml[:soap].Envelope 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/' do
            xml[:soap].Body do
              xml.Execute 'xmlns' => 'http://iveri.com/' do
                xml.validateRequest 'true'
                xml.protocol 'V_XML'
                xml.protocolVersion '2.0'
                xml.request vxml
              end
            end
          end
        end

        builder.to_xml
      end

      def build_vxml_request(action, options)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.V_XML('Version' => '2.0', 'CertificateID' => @options[:cert_id], 'Direction' => 'Request') do
            xml.Transaction('ApplicationID' => @options[:app_id], 'Command' => action, 'Mode' => mode) do
              yield(xml)
            end
          end
        end

        builder.doc.root.to_xml
      end

      def add_auth_purchase_params(post, money, payment_method, options)
        add_card_holder_authentication(post, options)
        add_amount(post, money, options)
        add_electronic_commerce_indicator(post, options)
        add_payment_method(post, payment_method, options)
      end

      def add_amount(post, money, options)
        post.Amount(amount(money))
        post.Currency(options[:currency] || default_currency)
      end

      def add_electronic_commerce_indicator(post, options)
        post.ElectronicCommerceIndicator(options[:eci]) if options[:eci]
      end

      def add_authorization(post, authorization, options)
        post.MerchantReference(split_auth(authorization)[2])
        post.TransactionIndex(split_auth(authorization)[1])
        post.OriginalRequestID(split_auth(authorization)[0])
      end

      def add_payment_method(post, payment_method, options)
        post.ExpiryDate("#{format(payment_method.month, :two_digits)}#{payment_method.year}")
        add_new_reference(post, options)
        post.CardSecurityCode(payment_method.verification_value)
        post.PAN(payment_method.number)
      end

      def add_new_reference(post, options)
        post.MerchantReference(options[:order_id] || generate_unique_id)
      end

      def add_card_holder_authentication(post, options)
        post.CardHolderAuthenticationID(options[:xid]) if options[:xid]
        post.CardHolderAuthenticationData(options[:cavv]) if options[:cavv]
      end

      def commit(post)
        raw_response = begin
          ssl_post(live_url, build_xml_envelope(post), headers(post))
        rescue ActiveMerchant::ResponseError => e
          e.response.body
        end

        parsed = parse(raw_response)
        succeeded = success_from(parsed)

        Response.new(
          succeeded,
          message_from(parsed, succeeded),
          parsed,
          authorization: authorization_from(parsed),
          error_code: error_code_from(parsed, succeeded),
          test: test?
        )
      end

      def mode
        test? ? 'Test' : 'Live'
      end

      def headers(post)
        {
          "Content-Type" => "text/xml; charset=utf-8",
          "Content-Length" => post.size.to_s,
          "SOAPAction" => "http://iveri.com/Execute"
        }
      end

      def parse(body)
        parsed = {}

        vxml = Nokogiri::XML(body).remove_namespaces!.xpath("//Envelope/Body/ExecuteResponse/ExecuteResult").inner_text
        doc = Nokogiri::XML(vxml)
        doc.xpath("*").each do |node|
          if (node.elements.empty?)
            parsed[underscore(node.name)] = node.text
          else
            node.elements.each do |childnode|
              parse_element(parsed, childnode)
            end
          end
        end
        parsed
      end

      def parse_element(parsed, node)
        if !node.attributes.empty?
          node.attributes.each do |a|
            parsed[underscore(node.name)+ "_" + underscore(a[1].name)] = a[1].value
          end
        end

        if !node.elements.empty?
          node.elements.each {|e| parse_element(parsed, e) }
        else
          parsed[underscore(node.name)] = node.text
        end
      end

      def success_from(response)
        response['result_status'] == '0'
      end

      def message_from(response, succeeded)
        if succeeded
          "Succeeded"
        else
          response['result_description'] || response['result_acquirer_description']
        end
      end

      def authorization_from(response)
        "#{response['transaction_request_id']}|#{response['transaction_index']}|#{response['merchant_reference']}"
      end

      def split_auth(authorization)
        request_id, transaction_index, merchant_reference = authorization.to_s.split('|')
        [request_id, transaction_index, merchant_reference]
      end

      def error_code_from(response, succeeded)
        unless succeeded
          response['result_code']
        end
      end

      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase
      end
    end
  end
end
