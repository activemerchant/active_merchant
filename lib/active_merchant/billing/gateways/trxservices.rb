require 'openssl'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TrxservicesGateway < Gateway
      self.test_url = 'https://api.trxservices.net'
      self.live_url = 'https://api.trxservices.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover,
                                  :jcb, :diners_club]

      self.homepage_url = 'http://www.trxservices.com/'
      self.display_name = 'Transaction Services'

      ACTION_CODE_MESSAGES = {
        '00' => 'Approved',
        'X0' => 'Validation Error (xsd schema failure)',
        'X1' => 'Validation Error (app business logic failure)',
        'X2' => 'Validation Error (db business logic failure)',
        'X3' => 'Security Violation (encryption, source, tran type, card type, etc.)',
        'X4' => 'System Offline (db exception)',
        'X5' => 'System Error (unhandled app exception)',
        'X6' => 'System Rule Decline',
        'X7' => 'Record Not Found (tran lookup)',
        'X8' => 'Rejected batch close/settle',
        'X9' => 'Failure to send alert',
        'XA' => 'Password has expired',
        'XB' => 'File error',
        'XD' => 'Duplicate found'
      }

      def initialize(options={})
        requires!(options, :iv, :key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)

        commit('Sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)

        commit('Auth', post)
      end

      def capture(money, options={})
        post = {}
        add_invoice(post, money, options)
        add_guid(post, options)

        commit('Capture', post)
      end

      def refund(money, options={})
        post = {}
        add_invoice(post, money, options)
        add_guid(post, options)

        commit('Return', post)
      end

      def void(money, options={})
        post = {}
        add_invoice(post, money, options)
        add_guid(post, options)

        commit('Cancel', post)
      end

      private

      def add_address(post, options)
        address = options[:address]

        post[:email] = options[:email]
        post[:postal_code] = address[:zip]
        post[:address] = address[:address1]
        post[:region] = address[:state]
        post[:city] = address[:city]
        post[:country] = address[:country]
      end

      def add_invoice(post, money, options)
        post[:amount] = "%.2f" % money
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        post[:number] = payment.number
        post[:cvv] = payment.verification_value
        post[:expire_month] = payment.month
        post[:expire_year] = payment.year
        post[:first_name] = payment.first_name
        post[:last_name] = payment.last_name
      end

      def add_guid(post, options)
        post[:guid] = options[:guid]
      end

      def parse(body)
        Nokogiri::XML(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)

        encrypted_response = parse(ssl_post(url, post_data(action, parameters))).at_xpath('//Response').content
        decrypted_response = modify_message('decrypt', encrypted_response)
        parsed_response = parse(add_response_tag(decrypted_response))

        Response.new(
          success_from(parsed_response),
          message_from(parsed_response),
          { response: add_response_tag(decrypted_response) },
          authorization: authorization_from(parsed_response),
          test: test?
        )
      end

      def success_from(response)
        response && (response.at_xpath('//ResponseCode').content == '00')
      end

      def message_from(response)
        ACTION_CODE_MESSAGES[response.at_xpath('//ResponseCode').content] ||= "Unknown action code"
      end

      def authorization_from(response)
        response.at_xpath('//Guid').content
      end

      def post_data(action, parameters = {})
        request = create_request(action, parameters)
        request = modify_message('encrypt', request)
        create_message(request)
      end

      def headers
        { 'Content-type' => 'text/xml' }
      end

      def create_request(action, parameters)
        if parameters[:guid]
          "<Detail>
            <TranType>Credit</TranType>
            <TranAction>#{action}</TranAction>
            <Amount>#{parameters[:amount]}</Amount>
            <CurrencyCode>840</CurrencyCode>
          </Detail>
          <Reference>
            <Guid>#{parameters[:guid]}</Guid>
          </Reference>"
        else
          "<Detail>
          <TranType>Credit</TranType>
          <TranAction>#{action}</TranAction>
          <Amount>#{parameters[:amount]}</Amount>
          <CurrencyCode>840</CurrencyCode>
          </Detail>
          <IndustryData>
          <Industry>CardNotPresent</Industry>
          <Eci>7</Eci>
          </IndustryData>
          <Account>
          <FirstName>#{parameters[:first_name]}</FirstName>
          <LastName>#{parameters[:last_name]}</LastName>
          <Email>#{parameters[:email]}</Email>
          <Pan>#{parameters[:number]}</Pan>
          <Cvv>#{parameters[:cvv]}</Cvv>
          <Expiration>#{create_expiration_date(parameters)}</Expiration>
          <Postal>#{parameters[:postal_code]}</Postal>
          <Address>#{parameters[:address]}</Address>
          <City>#{parameters[:city]}</City>
          <Region>#{parameters[:region]}</Region>
          <Country>#{parameters[:country]}</Country>
          </Account>"
        end
      end

      def create_message(request)
        "<Message><Request>#{request}</Request><Authentication><Client>207</Client><Source>1</Source></Authentication></Message>"
      end

      def create_expiration_date(parameters)
        parameters[:expire_month].to_s + parameters[:expire_year].to_s[-2..-1]
      end

      def modify_message(status, message)
        cipher = OpenSSL::Cipher.new('AES-256-CBC')

        case status
        when 'encrypt'
          cipher.encrypt
          cipher.key = [options[:key]].pack('H*')
          cipher.iv = [options[:iv]].pack('H*')
          encrypted_request = cipher.update(message) + cipher.final
          Base64.encode64(encrypted_request)
        when 'decrypt'
          cipher.decrypt
          cipher.key = [options[:key]].pack('H*')
          cipher.iv = [options[:iv]].pack('H*')
          cipher.padding = 0
          decoded_response = Base64.decode64(message)
          cipher.update(decoded_response) + cipher.final
        end
      end

      def add_response_tag(response)
        "<Response>#{response}</Response>"
      end
    end
  end
end
