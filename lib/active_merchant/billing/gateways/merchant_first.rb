require 'nokogiri'

# MerchantFirst's implementation only supports purchase, refund, void and store
# as we have been unable to get passed errors when trying to implement
# other methods, so in order to expedite this gateway, I am only
# implementing the methods that we can get some clearer answers and docs
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantFirstGateway < Gateway
      include Empty

      self.test_url = 'https://beta.mycardstorage.com/api/api.asmx'
      self.live_url = 'https://prod.mycardstorage.com/api/api.asmx'

      self.supported_countries = ['US', 'MX']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      self.homepage_url = 'http://merchantfirst.com/'
      self.display_name = 'Merchant First'
      self.money_format = :dollars

      SOAP_ACTION_NS = 'https://MyCardStorage.com/'
      SOAP_XMLNS = { xmlns: 'https://MyCardStorage.com/' }
      NS = {
        'xmlns:xsi'  => 'http://www.w3.org/2001/XMLSchema-instance',
        'xmlns:xsd'  => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope'
      }

      CARD_TYPE_MAP = {
        :visa => 4,
        :master => 3,
        :american_express => 1,
        :discover => 2,
        :diners_club => 5,
        :jcb => 7
      }.freeze

      # Merchant First | MyCardStorage is a gateway switch
      # we default to their own implementation, Merchant Partners
      GATEWAY_MAP = {
        'merchant partners'=> 1,
        'epp'=> 2,
        'capital bank'=> 3,
        'vantiv'=> 4,
        'smart platform'=> 5,
        'moneris'=> 6,
        'american express'=> 7,
        'mercury'=> 8
      }.freeze

      CURRENCY_MAP = {
        'USD' => 840, # United States Dollar
        'CRC' => 188, # Costa Rica Colon
        'GTQ' => 320, # Guatemalan Quetzal
        'MXN' => 484, # Mexico Peso
        'EUR' => 978, # Euro
        'CLP' => 152, # Chilean Peso
        'CAD' => 124, # Canadian Dollar
        'COP' => 170, # Colombia Peso
      }.freeze

      APPROVED, DECLINED, ERROR = "0", "1", "2"

      STANDARD_ERROR_CODE_MAPPING = {
        '1' => STANDARD_ERROR_CODE[:call_issuer],
        '2' => STANDARD_ERROR_CODE[:call_issuer],
        '4' => STANDARD_ERROR_CODE[:pickup_card],
        '5' => STANDARD_ERROR_CODE[:card_declined],
        '07' => STANDARD_ERROR_CODE[:pickup_card],
        '12' => STANDARD_ERROR_CODE[:processing_error],
        '14' => STANDARD_ERROR_CODE[:invalid_number],
        '26' => STANDARD_ERROR_CODE[:processing_error],
        '41' => STANDARD_ERROR_CODE[:pickup_card],
        '43' => STANDARD_ERROR_CODE[:pickup_card],
        '50' => STANDARD_ERROR_CODE[:processing_error],
        '51' => STANDARD_ERROR_CODE[:card_declined],
        '52' => STANDARD_ERROR_CODE[:incorrect_pin],
        '53' => STANDARD_ERROR_CODE[:processing_error],
        '54' => STANDARD_ERROR_CODE[:expired_card],
        '59' => STANDARD_ERROR_CODE[:processing_error],
        '61' => STANDARD_ERROR_CODE[:card_declined],
        '62' => STANDARD_ERROR_CODE[:card_declined],
        '64' => STANDARD_ERROR_CODE[:processing_error],
        '65' => STANDARD_ERROR_CODE[:card_declined],
        '82' => STANDARD_ERROR_CODE[:card_declined],
        '93' => STANDARD_ERROR_CODE[:call_issuer],
        '95' => STANDARD_ERROR_CODE[:card_declined],
        '96' => STANDARD_ERROR_CODE[:processing_error],
        '105' => STANDARD_ERROR_CODE[:processing_error],
        '201' => STANDARD_ERROR_CODE[:incorrect_pin],
        '209' => STANDARD_ERROR_CODE[:processing_error],
        '210' => STANDARD_ERROR_CODE[:invalid_cvc],
        '211' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '212' => STANDARD_ERROR_CODE[:config_error],
        '213' => STANDARD_ERROR_CODE[:config_error],
        '214' => STANDARD_ERROR_CODE[:config_error],
        '215' => STANDARD_ERROR_CODE[:config_error],
        '216' => STANDARD_ERROR_CODE[:config_error],
        '217' => STANDARD_ERROR_CODE[:config_error],
        '218' => STANDARD_ERROR_CODE[:config_error],
        '219' => STANDARD_ERROR_CODE[:config_error],
        '220' => STANDARD_ERROR_CODE[:config_error],
        '221' => STANDARD_ERROR_CODE[:config_error],
        '222' => STANDARD_ERROR_CODE[:config_error],
        '801' => STANDARD_ERROR_CODE[:processing_error],
        '966' => STANDARD_ERROR_CODE[:processing_error],
        '996' => STANDARD_ERROR_CODE[:processing_error],
        '997' => STANDARD_ERROR_CODE[:processing_error],
        '998' => STANDARD_ERROR_CODE[:processing_error],
        '999' => STANDARD_ERROR_CODE[:config_error],
        '1000' => STANDARD_ERROR_CODE[:config_error],
        '1001' => STANDARD_ERROR_CODE[:config_error],
        '1002' => STANDARD_ERROR_CODE[:card_declined]
      }.freeze

      def initialize(options={})
        requires!(options, :username, :password, :service_username, 
          :service_password, :merchant_id)
        super
      end

      def purchase(money, payment_method, options={})
        # if we are using a token, we need to call different
        # methods
        token_method = payment_method.is_a?(String) ? '_Token' : ''
        request = build_soap_request do |xml|
          xml.send("CreditSale#{token_method}_Soap", SOAP_XMLNS) do
            xml.creditCardSale do
              add_authentication(xml, 'CreditSale_Soap')
              add_credit_card(xml, payment_method, options)
              add_transaction_data(xml, money, options)
            end
          end
        end

        commit("CreditSale#{token_method}_Soap", request)
      end

      def refund(money, authorization, options={})
        options[:transaction_id] = authorization

        request = build_soap_request do |xml|
          xml.CreditCredit_Soap(SOAP_XMLNS) do
            xml.creditCardCredit do
              add_authentication(xml, 'CreditCredit_Soap')
              add_transaction_data(xml, money, options)
            end
          end
        end

        commit('CreditCredit_Soap', request)
      end

      def void(authorization, options={})
        options[:transaction_id] = authorization

        request = build_soap_request do |xml|
          xml.CreditVoid_Soap(SOAP_XMLNS) do
            xml.creditCardVoid do
              add_authentication(xml, 'CreditVoid_Soap')
              add_void_transaction_data(xml, options)
            end
          end
        end

        commit('CreditVoid_Soap', request)
      end

      def store(credit_card, options={})
        MultiResponse.run do |r|
          r.process { add_session }
          r.process { add_cof(credit_card, options.merge(session_id: r.authorization)) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<UserName>)[^<]*(</UserName>))i, '\1[FILTERED]\2').
          gsub(%r((<Password>)[^<]*(</Password>))i, '\1[FILTERED]\2').
          gsub(%r((<ServiceUserName>)[^<]*(</ServiceUserName>))i, '\1[FILTERED]\2').
          gsub(%r((<ServicePassword>)[^<]*(</ServicePassword>))i, '\1[FILTERED]\2').
          gsub(%r((<CardNumber>)[^<]*(</CardNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<CVV>)[^<]*(</CVV>))i, '\1[FILTERED]\2')
      end

      private

      def add_cof(credit_card, options={})
        request = build_soap_request do |xml|
          xml.AddCOF_Soap(SOAP_XMLNS) do
            xml.addToken do
              add_authentication(xml, 'AddCOF_Soap', options)
              add_credit_card(xml, credit_card, options)
            end
          end
        end

        commit('AddCOF_Soap', request)
      end

      def add_session
        request = build_soap_request do |xml|
          xml.AddSessionID_Soap(SOAP_XMLNS) do
            add_authentication(xml, 'AddSessionID_Soap')
          end
        end

        commit('AddSessionID_Soap', request)
      end

      def add_credit_card(xml, creditcard, options={})
        xml.TokenData do
          if creditcard.is_a?(String)
            xml.Token creditcard
          else
            xml.TokenType 0
            xml.CardNumber creditcard.number
            xml.CardType CARD_TYPE_MAP[card_brand(creditcard).to_sym]
            xml.ExpirationMonth format(creditcard.month, :two_digits)
            xml.ExpirationYear format(creditcard.year, :four_digits)
            xml.FirstName creditcard.first_name
            xml.LastName creditcard.last_name
            billing_address = options[:billing_address] || options[:address]
            add_address(xml, billing_address) if billing_address.present?
            xml.CVV creditcard.verification_value if creditcard.verification_value.present?
          end
        end
      end

      def add_address(xml, address)
        xml.StreetAddress address[:address1] unless empty?(address[:address1])
        xml.ZipCode address[:zip] unless empty?(address[:zip])
      end

      def add_country_code(xml, options={})
        address = options[:billing_address] || options[:address]
        return unless (address.present? && address.key?(:country))
        xml.CountryCode address[:country]
      end

      def add_transaction_data(xml, money, options={})
        xml.TransactionData do
          xml.Amount amount(money)
          add_country_code(xml, options)
          xml.CurrencyCode CURRENCY_MAP[(options[:currency] || currency(money)).upcase]
          xml.GatewayID GATEWAY_MAP[options.fetch(:gateway, 'merchant partners').downcase]
          xml.EmailAddress options[:email] unless empty?(options[:email])
          xml.MCSTransactionID options[:transaction_id] unless empty?(options[:transaction_id])
        end
      end

      def add_void_transaction_data(xml, options={})
        xml.TransactionData do
          xml.GatewayID GATEWAY_MAP[options.fetch(:gateway, 'merchant partners').downcase]
          xml.MCSTransactionID options[:transaction_id]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      # The AddSession and AddCOF have both different ways to pass
      # the auth information :-( thus the case statement.
      def add_authentication(xml, action, options={})
        auth_env = case action
          when 'AddSessionID_Soap'
            'serviceSecurity'
          else
            'ServiceSecurity'
          end
        xml.send(auth_env) do
          xml.ServiceUserName @options[:service_username]
          xml.ServicePassword @options[:service_password]
          xml.MCSAccountID @options[:merchant_id]
          # as +options+ is only passed in the +AddCOF_Soap+ method
          # we don't guard against that case with the +action+
          # check
          xml.SessionID options[:session_id] unless empty?(options[:session_id])
        end
      end

      def parse(action, body)
        parsed = {}

        doc = Nokogiri::XML(body).remove_namespaces!
        doc.xpath("//#{action}Response/#{action}Result/*").each do |node|
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

      def commit(action, xml, amount=nil)
        url = (test? ? test_url : live_url)
        response = parse(action, ssl_post(url, xml, headers(action)))
        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def success_from(action, response)
        if action == 'AddSessionID_Soap'
          response[:session_id].present?
        else
          response[:result_result_code] == APPROVED
        end
      end

      def message_from(action, response)
        response[:result_result_detail]
      end

      def authorization_from(action, response)
        if action == 'AddSessionID_Soap'
          response[:session_id]
        elsif action == 'AddCOF_Soap'
          response[:token_data_token]
        else
          response[:processor_transaction_id]
        end
      end

      def add_authentication_header(xml)
        xml.AuthHeader(SOAP_XMLNS) do
          xml.UserName(@options[:username])
          xml.Password(@options[:password])
        end
      end

      def headers(action)
        {
          'Content-Type'    => 'text/xml',
          'SOAPAction'      => "#{SOAP_ACTION_NS}#{action}",
        }
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['soap12'].Envelope(NS) do
            xml['soap12'].Header do
              add_authentication_header(xml)
            end
            xml['soap12'].Body do
              yield(xml)
            end
          end
        end

        builder.to_xml
      end

      def error_code_from(action, response)
        unless success_from(action, response)
          # default to processing error if the returned error code is not
          # found
          STANDARD_ERROR_CODE_MAPPING.fetch(response[:result_result_detail].scan(/\d+/).first, 12)
        end
      end
    end
  end
end
