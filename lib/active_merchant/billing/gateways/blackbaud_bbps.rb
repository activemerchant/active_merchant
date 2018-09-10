# frozen_string_literal: true
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BlackbaudBbpsGateway < Gateway
      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.blackbaud.com/'
      self.display_name = 'Blackbaud BBPS'

      ENV_NS = {
        'xmlns:xsi'     => 'http://www.w3.org/2001/XMLSchema-instance',
        'xmlns:xsd'     => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:soap12'  => 'http://www.w3.org/2003/05/soap-envelope'
      }.freeze
      SOAP_ACTION_NS = 'Blackbaud.AppFx.WebService.API.1'
      SOAP_XMLNS = { xmlns: SOAP_ACTION_NS }.freeze

      def initialize(options = {})
        requires!(options, :url, :username, :password)
        super
      end

      def store(credit_card, options = {})
        request = build_soap_request do |xml|
          xml.CreditCardVaultRequest(SOAP_XMLNS) do
            add_client_app(xml, options)
            add_payment(xml, credit_card)
          end
        end

        commit('CreditCardVault', request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<CardNumber>).+(</CardNumber>))i, '\1[FILTERED]\2')
      end

      private

      def client_app(options = {})
        options[:client_app] || 'Evergiving'
      end

      def database_to_use(options = {})
        options[:database_to_use] || 'BBInfinity'
      end

      def add_client_app(xml, options)
        xml.ClientAppInfo(
          REDatabaseToUse: database_to_use(options),
          ClientAppName: client_app(options),
          xmlns: SOAP_ACTION_NS
        )
      end

      def add_payment(xml, payment)
        xml.CreditCards do
          xml.CreditCardInfo do
            xml.CardHolder payment.name
            xml.CardNumber payment.number
            xml.ExpirationDate do
              xml.Month format(payment.month, :two_digits)
              xml.Year format(payment.year, :four_digits)
            end
          end
        end
      end

      def parse(action, body)
        parsed = {}

        doc = Nokogiri::XML(body).remove_namespaces!
        doc.xpath("//#{action}Response/*").each do |node|
          if (node.elements.empty?)
            parsed[node.name.underscore.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name}_#{childnode.name}"
              parsed[name.underscore.to_sym] = childnode.text
            end
          end
        end

        parsed
      end

      def basic_auth
        Base64.strict_encode64("#{@options[:username]}:#{@options[:password]}")
      end

      def headers(action)
        {
          'Content-Type'    => 'text/xml; charset=utf-8',
          'Host'            => hostname,
          'SOAPAction'      => "#{SOAP_ACTION_NS}/#{action}",
          'Authorization'   => "Basic #{basic_auth}"
        }
      end

      def hostname
        URI.parse(normalised_url).host
      end

      def normalised_url
        # note: URI will throw an exception if `@options[:url]` does not contain
        # the protocol so we do this naive dance
        @options[:url].start_with?('http') ? @options[:url] : "https://#{@options[:url]}"
      end

      def url
        normalised_url.strip
      end

      def commit(action, xml)
        response = parse(action, ssl_post(url, xml, headers(action)))

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?
        )
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['soap12'].Envelope(ENV_NS) do
            xml['soap12'].Body do
              yield(xml)
            end
          end
        end

        builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      def success_from(_action, response)
        response[:status] == 'Success'
      end

      def message_from(action, response)
        if success_from(action, response)
          response[:status]
        else
          response[:error_message]
        end
      end

      def authorization_from(_action, response)
        response[:token]
      end
    end
  end
end
