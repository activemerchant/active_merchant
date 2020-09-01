require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BamboraApacGateway < Gateway
      self.live_url = 'https://www.bambora.co.nz/interface/api'
      self.test_url = 'https://demo.bambora.co.nz/interface/api'

      self.supported_countries = %w[AU NZ]
      self.supported_cardtypes = %i[visa master american_express diners_club jcb]

      self.homepage_url = 'http://www.bambora.com/'
      self.display_name = 'Bambora Asia-Pacific'

      self.money_format = :cents

      STANDARD_ERROR_CODE_MAPPING = {
        '05' => STANDARD_ERROR_CODE[:card_declined],
        '06' => STANDARD_ERROR_CODE[:processing_error],
        '14' => STANDARD_ERROR_CODE[:invalid_number],
        '54' => STANDARD_ERROR_CODE[:expired_card]
      }

      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      def purchase(money, payment, options={})
        commit('SubmitSinglePayment') do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            xml.Amount amount(money)
            xml.TrnType '1'
            add_payment(xml, payment)
            add_credentials(xml, options)
            xml.TrnSource options[:ip]
          end
        end
      end

      def authorize(money, payment, options={})
        commit('SubmitSinglePayment') do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            xml.Amount amount(money)
            xml.TrnType '2'
            add_payment(xml, payment)
            add_credentials(xml, options)
            xml.TrnSource options[:ip]
          end
        end
      end

      def capture(money, authorization, options={})
        commit('SubmitSingleCapture') do |xml|
          xml.Capture do
            xml.Receipt authorization
            xml.Amount amount(money)
            add_credentials(xml, options)
          end
        end
      end

      def refund(money, authorization, options={})
        commit('SubmitSingleRefund') do |xml|
          xml.Refund do
            xml.Receipt authorization
            xml.Amount amount(money)
            add_credentials(xml, options)
          end
        end
      end

      def void(authorization, options={})
        commit('SubmitSingleVoid') do |xml|
          xml.Void do
            xml.Receipt authorization
            xml.Amount amount(options[:amount])
            add_credentials(xml, options)
          end
        end
      end

      def store(payment, options={})
        commit('TokeniseCreditCard') do |xml|
          xml.TokeniseCreditCard do
            xml.CardNumber payment.number
            xml.ExpM format(payment.month, :two_digits)
            xml.ExpY format(payment.year, :four_digits)
            xml.TokeniseAlgorithmID options[:tokenise_algorithm_id] || 2
            xml.UserName @options[:username]
            xml.Password @options[:password]
          end
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<CardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<CVN>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<Password>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      def add_credentials(xml, options)
        xml.AccountNumber options[:account_number] if options[:account_number]
        xml.Security do
          xml.UserName @options[:username]
          xml.Password @options[:password]
        end
      end

      def add_payment(xml, payment)
        if payment.is_a?(String)
          add_token(xml, payment)
        else
          add_credit_card(xml, payment)
        end
      end

      def add_token(xml, payment)
        xml.CreditCard do
          xml.TokeniseAlgorithmID options[:tokenise_algorithm_id] || 2
          xml.CardNumber payment
        end
      end

      def add_credit_card(xml, payment)
        xml.CreditCard Registered: 'False' do
          xml.CardNumber payment.number
          xml.ExpM format(payment.month, :two_digits)
          xml.ExpY format(payment.year, :four_digits)
          xml.CVN payment.verification_value
          xml.CardHolderName payment.name
        end
      end

      def parse(body)
        element = Nokogiri::XML(body).root.first_element_child.first_element_child

        response = {}
        doc = Nokogiri::XML(element)
        doc.root.elements.each do |e|
          response[e.name.underscore.to_sym] = e.inner_text
        end
        response
      end

      def commit(action, &block)
        headers = {
          'Content-Type' => 'text/xml; charset=utf-8',
          'SOAPAction' => "http://www.ippayments.com.au/interface/api/#{endpoint(action)}/#{action}"
        }
        response = parse(ssl_post("#{commit_url}/#{endpoint(action)}.asmx", new_submit_xml(action, &block), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(response),
          test: test?
        )
      end

      def new_submit_xml(action)
        xml = Builder::XmlMarkup.new(indent: 2)
        xml.instruct!
        xml.soap :Envelope, 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/' do
          xml.soap :Body do
            xml.__send__(action, 'xmlns' => "http://www.ippayments.com.au/interface/api/#{endpoint(action)}") do
              if action == 'TokeniseCreditCard'
                xml.tokeniseCreditCardXML do
                  inner_xml = Builder::XmlMarkup.new(indent: 2)
                  yield(inner_xml)
                  xml.cdata!(inner_xml.target!)
                end
              else
                xml.trnXML do
                  inner_xml = Builder::XmlMarkup.new(indent: 2)
                  yield(inner_xml)
                  xml.cdata!(inner_xml.target!)
                end
              end
            end
          end
        end
        xml.target!
      end

      def endpoint(action)
        action == 'TokeniseCreditCard' ? 'sipp' : 'dts'
      end

      def commit_url
        test? ? test_url : live_url
      end

      def success_from(response)
        response[:response_code] == '0' || response[:return_value] == '0'
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response[:declined_code]]
      end

      def message_from(response)
        success_from(response) ? 'Succeeded' : response[:declined_message]
      end

      def authorization_from(response)
        response[:receipt] || response[:token]
      end
    end
  end
end
