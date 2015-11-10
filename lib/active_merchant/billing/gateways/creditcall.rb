require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CreditcallGateway < Gateway
      include Empty

      self.test_url = 'https://test.cardeasexml.com/generic.cex'
      self.live_url = 'https://live.cardeasexml.com/generic.cex'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.creditcall.com'
      self.display_name = 'Creditcall'

      def initialize(options={})
        requires!(options, :terminal_id, :transaction_key)
        super
      end

      def purchase(money, payment_method, options={})
        multi_response = MultiResponse.run do |r|
          r.process { authorize(money, payment_method, options) }
          r.process { capture(money, r.authorization, options) }
        end

        Response.new(
          multi_response.primary_response.success?,
          multi_response.primary_response.message,
          multi_response.primary_response.params,
          authorization: multi_response.responses.first.authorization,
          test: test?
        )
      end

      def authorize(money, payment_method, options={})
        request = build_xml_request do |xml|
          add_transaction_details(xml, money, nil, "Auth", options)
          add_terminal_details(xml, options)
          add_card_details(xml, payment_method, options)
        end

        commit(request)
      end

      def capture(money, authorization, options={})
        request = build_xml_request do |xml|
          add_transaction_details(xml, money, authorization, "Conf", options)
          add_terminal_details(xml, options)
        end

        commit(request)
      end

      def refund(money, authorization, options={})
        request = build_xml_request do |xml|
          add_transaction_details(xml, money, authorization, "Refund", options)
          add_terminal_details(xml, options)
        end

        commit(request)
      end

      def void(authorization, options={})
        request = build_xml_request do |xml|
          add_transaction_details(xml, nil, authorization, "Void", options)
          add_terminal_details(xml, options)
        end

        commit(request)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<TransactionKey>).+?(</TransactionKey>))i, '\1[FILTERED]\2').
          gsub(%r((<PAN>).+?(</PAN>))i, '\1[FILTERED]\2').
          gsub(%r((<CSC>).+?(</CSC>))i, '\1[FILTERED]\2')
      end

      private

      def build_xml_request
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.Request(type: "CardEaseXML", version: "1.0.0") do
            yield(xml)
          end
        end
        builder.to_xml
      end

      def add_transaction_details(xml, amount, authorization, type, options={})
        xml.TransactionDetails do
          xml.MessageType type
          xml.Amount(unit: "Minor"){ xml.text(amount) } if amount
          xml.CardEaseReference authorization if authorization
          xml.VoidReason "01" if type == "Void"
        end
      end

      def add_terminal_details(xml, options={})
        xml.TerminalDetails do
          xml.TerminalID @options[:terminal_id]
          xml.TransactionKey @options[:transaction_key]
          xml.Software(version: "SoftwareVersion"){ xml.text("SoftwareName") }
        end
      end

      def add_card_details(xml, payment_method, options={})
        xml.CardDetails do
          xml.Manual(type: "cnp") do
            xml.PAN payment_method.number
            xml.ExpiryDate exp_date(payment_method)
            xml.CSC payment_method.verification_value unless empty?(payment_method.verification_value)
          end

          if address = options[:billing_address]
            xml.AdditionalVerification do
              xml.Address address[:address1]
              xml.Zip address[:zip]
            end
          end
        end
      end

      def exp_date(payment_method)
        "#{format(payment_method.year, :two_digits)}#{format(payment_method.month, :two_digits)}"
      end

      def parse(body)
        response = {}
        xml = Nokogiri::XML(body)

        node = xml.xpath("//Response/TransactionDetails")
        node.children.each do |childnode|
          response[childnode.name] = childnode.text
        end

        node = xml.xpath("//Response/Result")
        node.children.each do |childnode|
          if childnode.elements.empty?
            response[childnode.name] = childnode.text
          else
            childnode_to_response(response, childnode)
          end
        end

        response
      end

      def childnode_to_response(response, childnode)
        childnode.elements.each do |element|
          if element.name == "Error"
            response["ErrorCode"] = element.attr("code")
            response["ErrorMessage"] = element.text
          else
            response[element.name] = element.text
          end
        end
      end

      def commit(parameters)
        response = parse(ssl_post(url, parameters))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?
        )
      end

      def url
        test? ? test_url : live_url
      end

      def success_from(response)
        response["LocalResult"] == "0" || response["LocalResult"] == "00"
      end

      def message_from(response)
        if success_from(response)
          "Succeeded"
        else
          response["ErrorMessage"]
        end
      end

      def authorization_from(response)
        response["CardEaseReference"]
      end

    end
  end
end
