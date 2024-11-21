require 'nokogiri'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class IveriGateway < Gateway
      class_attribute :iveri_url

      self.live_url = self.test_url = 'https://portal.nedsecure.co.za/iVeriWebService/Service.asmx'
      self.iveri_url = 'https://portal.host.iveri.com/iVeriWebService/Service.asmx'

      self.supported_countries = %w[US ZA GB]
      self.default_currency = 'ZAR'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express]

      self.homepage_url = 'http://www.iveri.com'
      self.display_name = 'iVeri'

      def initialize(options = {})
        requires!(options, :app_id, :cert_id)
        super
      end

      def purchase(money, payment_method, options = {})
        post = build_vxml_request('Debit', options) do |xml|
          add_auth_purchase_params(xml, money, payment_method, options)
        end

        commit(post)
      end

      def authorize(money, payment_method, options = {})
        post = build_vxml_request('Authorisation', options) do |xml|
          add_auth_purchase_params(xml, money, payment_method, options)
        end

        commit(post)
      end

      def capture(money, authorization, options = {})
        post = build_vxml_request('Debit', options) do |xml|
          add_authorization(xml, authorization, options)
        end

        commit(post)
      end

      def refund(money, authorization, options = {})
        post = build_vxml_request('Credit', options) do |xml|
          add_amount(xml, money, options)
          add_authorization(xml, authorization, options)
        end

        commit(post)
      end

      def void(authorization, options = {})
        txn_type = options[:reference_type] == :authorize ? 'AuthorisationReversal' : 'Void'
        post = build_vxml_request(txn_type, options) do |xml|
          add_authorization(xml, authorization, options)
        end

        commit(post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options.merge(reference_type: :authorize)) }
        end
      end

      def verify_credentials
        void = void('', options)
        return true if void.message == 'Missing OriginalMerchantTrace'

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
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml[:soap].Envelope 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/' do
            xml[:soap].Body do
              xml.Execute 'xmlns' => 'http://iveri.com/' do
                xml.validateRequest('false')
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
        add_electronic_commerce_indicator(post, options) unless options[:three_d_secure]
        add_payment_method(post, payment_method, options)
        add_three_ds(post, options)
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
        raw_response =
          begin
            ssl_post(url, build_xml_envelope(post), headers(post))
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

      def url
        @options[:url_override].to_s == 'iveri' ? iveri_url : live_url
      end

      def headers(post)
        {
          'Content-Type' => 'text/xml; charset=utf-8',
          'Content-Length' => post.size.to_s,
          'SOAPAction' => 'http://iveri.com/Execute'
        }
      end

      def parse(body)
        parsed = {}

        vxml = Nokogiri::XML(body).remove_namespaces!.xpath('//Envelope/Body/ExecuteResponse/ExecuteResult').inner_text
        doc = Nokogiri::XML(vxml)
        doc.xpath('*').each do |node|
          if node.elements.empty?
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
            parsed[underscore(node.name) + '_' + underscore(a[1].name)] = a[1].value
          end
        end

        if node.elements.empty?
          parsed[underscore(node.name)] = node.text
        else
          node.elements.each { |e| parse_element(parsed, e) }
        end
      end

      def success_from(response)
        response['result_status'] == '0'
      end

      def message_from(response, succeeded)
        if succeeded
          'Succeeded'
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
        response['result_code'] unless succeeded
      end

      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
          gsub(/([a-z\d])([A-Z])/, '\1_\2').
          tr('-', '_').
          downcase
      end

      def add_three_ds(post, options)
        return unless three_d_secure = options[:three_d_secure]

        post.ElectronicCommerceIndicator(formatted_three_ds_eci(three_d_secure[:eci])) if three_d_secure[:eci]
        post.CardHolderAuthenticationID(three_d_secure[:xid]) if three_d_secure[:xid]
        post.CardHolderAuthenticationData(three_d_secure[:cavv]) if three_d_secure[:cavv]
        post.ThreeDSecure_ProtocolVersion(three_d_secure[:version]) if three_d_secure[:version]
        post.ThreeDSecure_DSTransID(three_d_secure[:ds_transaction_id]) if three_d_secure[:ds_transaction_id]
        post.ThreeDSecure_VEResEnrolled(formatted_enrollment(three_d_secure[:enrolled])) if three_d_secure[:enrolled]
      end

      def formatted_enrollment(val)
        case val
        when 'Y', 'N', 'U' then val
        when true, 'true' then 'Y'
        when false, 'false' then 'N'
        end
      end

      def formatted_three_ds_eci(val)
        case val
        when '05', '02' then 'ThreeDSecure'
        when '06', '01' then 'ThreeDSecureAttempted'
        when '07' then 'SecureChannel'
        else val
        end
      end
    end
  end
end
