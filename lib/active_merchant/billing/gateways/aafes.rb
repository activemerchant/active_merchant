require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AafesGateway < Gateway
      self.test_url = 'https://uat-stargate.aafes.com:1009/stargate/1/creditmessage'
      self.live_url = ''

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      # self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.myecp.com/'
      self.display_name = 'AAFES'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :identity_uuid)
        @identity_uuid = options[:identity_uuid]
        super
      end

      # def purchase(amount, payment, options={})
      #   request = build_xml_request do |xml|
      #     add_headers(xml, options)
      #     add_milstar_purchase(xml, amount, payment, options)
      #   end

      #   commit(request)
      # end

      def authorize(amount, payment, options={})
        request = build_xml_request do |xml|
          add_headers(xml, options)
          add_milstar_auth(xml, amount, payment, options)
        end

        commit(request)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
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
        transcript
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def parse(body)
        xml = Nokogiri::XML(body)
        Hash.from_xml(xml.to_s)['Message']
      end

      def commit(request)
        url = (test? ? test_url : live_url)
        response =
          begin
            parse(ssl_post(url, request, headers))
          rescue StandardError => error
            parse(error.response.body)
          end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers
        {
          'Content-Type' => 'application/xml'
        }
      end

      def success_from(response)
        return true if response.dig('Response', 'ReasonCode').to_i.between?(0, 100)

        return false
      end

      def message_from(response)
        response.dig('Response', 'ResponseType')
      end

      def authorization_from(response) end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['cm'].Message(
            'TypeCode' => 'Request',
            'MajorVersion' => '3',
            'MinorVersion' => '4',
            'FixVersion' => '0',
            'xmlns:cm' => 'http://www.aafes.com/credit') do
            yield(xml)
          end
        end

        builder.to_xml
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

      def add_headers(xml, options)
        xml['cm'].Header do
          xml['cm'].IdentityUUID(@identity_uuid)
          xml['cm'].LocalDateTime(Time.now.utc.iso8601)
          xml['cm'].SettleIndicator(false)
          xml['cm'].OrderNumber(options[:order_id])
          xml['cm'].transactionId(options[:transaction_id])
          xml['cm'].termId(options[:term_id])
          xml['cm'].Comment(options[:comment])
          xml['cm'].CustomerID(options[:customer_id])
        end
      end

      def add_milstar_auth(xml, amount, payment, options)
        xml['cm'].Request('RRN' => options[:rrn]) do
          xml['cm'].Media('Milstar')
          xml['cm'].RequestType('Sale')
          xml['cm'].InputType('Keyed')
          xml['cm'].Token('Token')
          xml['cm'].Account(payment.payment_data)
          xml['cm'].Expiration(payment.metadata[:expiration])
          xml['cm'].AmountField(amount)
          xml['cm'].PlanNumbers do
            xml['cm'].PlanNumber(options[:plan_number])
          end
          xml['cm'].DescriptionField(options[:description])
          xml['cm'].AddressVerificationService do
            xml['cm'].BillingZipCode(payment.metadata[:zip])
          end
        end
      end
    end
  end
end
