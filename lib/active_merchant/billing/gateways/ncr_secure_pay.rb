require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NcrSecurePayGateway < Gateway
      self.test_url = 'https://testbox.monetra.com:8665/'
      self.live_url = 'https://portal.ncrsecurepay.com:8444/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.ncrretailonline.com'
      self.display_name = 'NCR Secure Pay'

      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)

        commit('preauth', post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_invoice(post, money, options)

        commit('preauthcomplete', post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_invoice(post, money, options)

        commit('credit', post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)
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
        transcript.gsub(%r((<password>)[^<]*(</password>))i, '\1[FILTERED]\2').
          gsub(%r((<account>)[^<]*(</account>))i, '\1[FILTERED]\2').
          gsub(%r((<cv>)[^<]*(</cv>))i, '\1[FILTERED]\2')
      end

      private

      def add_reference(post, reference)
        post[:ttid] = reference
      end

      def add_address(post, payment, options)
        address = options[:billing_address] || options[:address]
        post[:zip] = address[:zip]
        post[:street] = address[:address1]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:descmerch] = options[:merchant] if options[:merchant]
        post[:ordernum] = options[:order_id] if options[:order_id]
        post[:comments] = options[:description] if options[:description]
      end

      def add_payment(post, payment)
        post[:cardholdername] = payment.name
        post[:account] = payment.number
        post[:cv] = payment.verification_value
        post[:expdate] = expdate(payment)
      end

      def parse(body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!
        response = doc.xpath("/MonetraResp/Resp")[0]
        resp_params = {}

        response.elements.each do |node|
          resp_params[node.name.downcase.to_sym] = node.text
        end
        resp_params
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, request_body(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response[:code] == "AUTH"
      end

      def message_from(response)
        response[:verbiage]
      end

      def authorization_from(response)
        response[:ttid]
      end

      def request_body(action, parameters = {})
        Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
          xml.MonetraTrans do
            xml.Trans(identifier: parameters.delete(:identifier) || "1") do
              xml.username(options[:username])
              xml.password(options[:password])
              xml.action(action)
              parameters.each do |name, value|
                xml.send(name, value)
              end
            end
          end
        end.to_xml
      end

      def error_code_from(response)
        unless success_from(response)
          response[:msoft_code] || response[:phard_code]
        end
      end
    end
  end
end
