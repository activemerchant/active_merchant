require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TelrGateway < Gateway
      self.display_name = "Telr"
      self.homepage_url = "http://www.telr.com/"

      self.live_url = "https://secure.telr.com/gateway/remote.xml"

      self.supported_countries = ["AE", "IN", "SA"]
      self.default_currency = "AED"
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :maestro, :solo, :jcb]

      CVC_CODE_TRANSLATOR = {
        'Y' => 'M',
        'N' => 'N',
        'X' => 'P',
        'E' => 'U',
      }

      AVS_CODE_TRANSLATOR = {
        'Y' => 'M',
        'P' => 'A',
        'N' => 'N',
        'X' => 'I',
        'E' => 'R'
      }

      def initialize(options={})
        requires!(options, :merchant_id, :api_key)
        super
      end

      def purchase(amount, payment_method, options={})
        commit(:purchase, amount, options[:currency]) do |doc|
          add_invoice(doc, "sale", amount, payment_method, options)
          add_payment_method(doc, payment_method, options)
          add_customer_data(doc, payment_method, options)
        end
      end

      def authorize(amount, payment_method, options={})
        commit(:authorize, amount, options[:currency]) do |doc|
          add_invoice(doc, "auth", amount, payment_method, options)
          add_payment_method(doc, payment_method, options)
          add_customer_data(doc, payment_method, options)
        end
      end

      def capture(amount, authorization, options={})
        commit(:capture) do |doc|
          add_invoice(doc, "capture", amount, authorization, options)
        end
      end

      def void(authorization, options={})
        _, amount, currency = split_authorization(authorization)
        commit(:void) do |doc|
          add_invoice(doc, "void", amount.to_i, authorization, options.merge(currency: currency))
        end
      end

      def refund(amount, authorization, options={})
        commit(:refund) do |doc|
          add_invoice(doc, "refund", amount, authorization, options)
        end
      end

      def verify(credit_card, options={})
        commit(:verify) do |doc|
          add_invoice(doc, "verify", 100, credit_card, options)
          add_payment_method(doc, credit_card, options)
          add_customer_data(doc, credit_card, options)
        end
      end

      def verify_credentials
        response = void("0")
        !["01", "04"].include?(response.error_code)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
        gsub(%r((<Number>)[^<]+(<))i, '\1[FILTERED]\2').
        gsub(%r((<CVV>)[^<]+(<))i, '\1[FILTERED]\2').
        gsub(%r((<Key>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      def add_invoice(doc, action, money, payment_method, options)
        doc.tran do
          doc.type(action)
          doc.amount(amount(money))
          doc.currency(options[:currency] || currency(money))
          doc.cartid(options[:order_id])
          doc.class_(transaction_class(action, payment_method))
          doc.description(options[:description] || "Description")
          doc.test_(test_mode)
          add_ref(doc, action, payment_method)
        end
      end

      def add_payment_method(doc, payment_method, options)
        return if payment_method.is_a?(String)
        doc.card do
          doc.number(payment_method.number)
          doc.cvv(payment_method.verification_value)
          doc.expiry do
            doc.month(format(payment_method.month, :two_digits))
            doc.year(format(payment_method.year, :four_digits))
          end
        end
      end

      def add_customer_data(doc, payment_method, options)
        return if payment_method.is_a?(String)
        doc.billing do
          doc.name do
            doc.first(payment_method.first_name)
            doc.last(payment_method.last_name)
          end
          doc.email(options[:email] || "unspecified@email.com")
          doc.ip(options[:ip]) if options[:ip]
          doc.address do
            add_address(doc, options)
          end
        end
      end

      def add_address(doc, options)
        address = options[:billing_address] || {}
        doc.country(address[:country] ? lookup_country_code(address[:country]) : "NA")
        doc.city(address[:city] || "City")
        doc.line1(address[:address1] || "Address")
        return unless address
        doc.line2(address[:address2]) if address[:address2]
        doc.zip(address[:zip]) if address[:zip]
        doc.region(address[:state]) if address[:state]
      end

      def add_ref(doc, action, payment_method)
        if ["capture", "refund", "void"].include?(action) || payment_method.is_a?(String)
          doc.ref(split_authorization(payment_method)[0])
        end
      end

      def add_authentication(doc)
        doc.store(@options[:merchant_id])
        doc.key(@options[:api_key])
      end

      def lookup_country_code(code)
        country = Country.find(code) rescue nil
        country.code(:alpha2)
      end

      def commit(action, amount=nil, currency=nil)
        currency = default_currency if currency == nil
        request = build_xml_request { |doc| yield(doc) }
        response = ssl_post(live_url, request, headers)
        parsed = parse(response)

        succeeded = success_from(parsed)
        Response.new(
          succeeded,
          message_from(succeeded, parsed),
          parsed,
          authorization: authorization_from(action, parsed, amount, currency),
          avs_result: avs_result(parsed),
          cvv_result: cvv_result(parsed),
          error_code: error_code_from(succeeded, parsed),
          test: test?
        )
      end

      def root_attributes
        {
          store: @options[:merchant_id],
          key: @options[:api_key]
        }
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.remote do |doc|

            add_authentication(doc)
            yield(doc)
          end
        end

        builder.doc.to_xml
      end

      def test_mode
        test? ? '1' : '0'
      end

      def transaction_class(action, payment_method)
        if payment_method.is_a?(String) && action == "sale"
          return "cont"
        else
          return "moto"
        end
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath("*").each do |node|
          if (node.elements.size == 0)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end unless doc.root.nil?

        response
      end

      def authorization_from(action, response, amount, currency)
        auth = response[:tranref]
        auth = [auth, amount, currency].join('|')
        auth
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def success_from(response)
        response[:status] == "A"
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response[:message]
        end
      end

      def error_code_from(succeeded, response)
        unless succeeded
          response[:code]
        end
      end

      def cvv_result(parsed)
        CVVResult.new(CVC_CODE_TRANSLATOR[parsed[:cvv]])
      end

      def avs_result(parsed)
        AVSResult.new(code: AVS_CODE_TRANSLATOR[parsed[:avs]])
      end

      def headers
        {
          "Content-Type" => "text/xml"
        }
      end
    end
  end
end
