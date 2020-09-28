require 'active_merchant/billing/gateways/ideal/ideal_response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Implementation contains some simplifications
    # - does not support multiple subID per merchant
    # - language is fixed to 'nl'
    class IdealBaseGateway < Gateway
      class_attribute :server_pem, :pem_password, :default_expiration_period
      self.default_expiration_period = 'PT10M'
      self.default_currency = 'EUR'
      self.pem_password = true

      self.abstract_class = true

      # These constants will never change for most users
      AUTHENTICATION_TYPE = 'SHA1_RSA'
      LANGUAGE = 'nl'
      SUB_ID = '0'
      API_VERSION = '1.1.0'

      def initialize(options = {})
        requires!(options, :login, :password, :pem)

        options[:pem_password] = options[:password]
        super
      end

      # Setup transaction. Get redirect_url from response.service_url
      def setup_purchase(money, options = {})
        requires!(options, :issuer_id, :return_url, :order_id, :currency, :description, :entrance_code)

        commit(build_transaction_request(money, options))
      end

      # Check status of transaction and confirm payment
      # transaction_id must be a valid transaction_id from a prior setup.
      def capture(transaction, options = {})
        options[:transaction_id] = transaction
        commit(build_status_request(options))
      end

      # Get list of issuers from response.issuer_list
      def issuers
        commit(build_directory_request)
      end

      private

      def url
        (test? ? test_url : live_url)
      end

      def token
        @token ||= create_fingerprint(@options[:pem])
      end

      # <?xml version="1.0" encoding="UTF-8"?>
      # <AcquirerTrxReq xmlns="http://www.idealdesk.com/Message" version="1.1.0">
      #  <createDateTimeStamp>2001-12-17T09:30:47.0Z</createDateTimeStamp>
      #  <Issuer>
      #   <issuerID>1003</issuerID>
      #  </Issuer>
      #   <Merchant>
      #     <merchantID>000123456</merchantID>
      #     <subID>0</subID>
      #     <authentication>passkey</authentication>
      #     <token>1</token>
      #     <tokenCode>3823ad872eff23</tokenCode>
      #     <merchantReturnURL>https://www.mijnwinkel.nl/betaalafhandeling
      #      </merchantReturnURL>
      #   </Merchant>
      #   <Transaction>
      #     <purchaseID>iDEAL-aankoop 21</purchaseID>
      #     <amount>5999</amount>
      #     <currency>EUR</currency>
      #     <expirationPeriod>PT3M30S</expirationPeriod>
      #     <language>nl</language>
      #     <description>Documentensuite</description>
      #     <entranceCode>D67tyx6rw9IhY71</entranceCode>
      #   </Transaction>
      # </AcquirerTrxReq>
      def build_transaction_request(money, options)
        date_time_stamp = create_time_stamp
        message  = date_time_stamp +
                   options[:issuer_id] +
                   @options[:login] +
                   SUB_ID +
                   options[:return_url] +
                   options[:order_id] +
                   money.to_s +
                   (options[:currency] || currency(money)) +
                   LANGUAGE +
                   options[:description] +
                   options[:entrance_code]
        token_code = sign_message(@options[:pem], @options[:password], message)

        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!
        xml.tag! 'AcquirerTrxReq', 'xmlns' => 'http://www.idealdesk.com/Message', 'version' => API_VERSION do
          xml.tag! 'createDateTimeStamp', date_time_stamp
          xml.tag! 'Issuer' do
            xml.tag! 'issuerID', options[:issuer_id]
          end
          xml.tag! 'Merchant' do
            xml.tag! 'merchantID', @options[:login]
            xml.tag! 'subID', SUB_ID
            xml.tag! 'authentication', AUTHENTICATION_TYPE
            xml.tag! 'token', token
            xml.tag! 'tokenCode', token_code
            xml.tag! 'merchantReturnURL', options[:return_url]
          end
          xml.tag! 'Transaction' do
            xml.tag! 'purchaseID', options[:order_id]
            xml.tag! 'amount', money
            xml.tag! 'currency', options[:currency]
            xml.tag! 'expirationPeriod', options[:expiration_period] || default_expiration_period
            xml.tag! 'language', LANGUAGE
            xml.tag! 'description', options[:description]
            xml.tag! 'entranceCode', options[:entrance_code]
          end
          xml.target!
        end
      end

      # <?xml version="1.0" encoding="UTF-8"?>
      # <AcquirerStatusReq xmlns="http://www.idealdesk.com/Message" version="1.1.0">
      #  <createDateTimeStamp>2001-12-17T09:30:47.0Z</createDateTimeStamp>
      #  <Merchant>
      #   <merchantID>000123456</merchantID>
      #   <subID>0</subID>
      #   <authentication>keyed hash</authentication>
      #   <token>1</token>
      #   <tokenCode>3823ad872eff23</tokenCode>
      #  </Merchant>
      #  <Transaction>
      #   <transactionID>0001023456789112</transactionID>
      #  </Transaction>
      # </AcquirerStatusReq>
      def build_status_request(options)
        datetimestamp = create_time_stamp
        message = datetimestamp + @options[:login] + SUB_ID + options[:transaction_id]
        tokenCode = sign_message(@options[:pem], @options[:password], message)

        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!
        xml.tag! 'AcquirerStatusReq', 'xmlns' => 'http://www.idealdesk.com/Message', 'version' => API_VERSION do
          xml.tag! 'createDateTimeStamp', datetimestamp
          xml.tag! 'Merchant' do
            xml.tag! 'merchantID', @options[:login]
            xml.tag! 'subID', SUB_ID
            xml.tag! 'authentication' , AUTHENTICATION_TYPE
            xml.tag! 'token', token
            xml.tag! 'tokenCode', tokenCode
          end
          xml.tag! 'Transaction' do
            xml.tag! 'transactionID', options[:transaction_id]
          end
        end
        xml.target!
      end

      # <?xml version="1.0" encoding="UTF-8"?>
      # <DirectoryReq xmlns="http://www.idealdesk.com/Message" version="1.1.0">
      #  <createDateTimeStamp>2001-12-17T09:30:47.0Z</createDateTimeStamp>
      #  <Merchant>
      #   <merchantID>000000001</merchantID>
      #   <subID>0</subID>
      #   <authentication>1</authentication>
      #   <token>hashkey</token>
      #   <tokenCode>WajqV1a3nDen0be2r196g9FGFF=</tokenCode>
      #  </Merchant>
      # </DirectoryReq>
      def build_directory_request
        datetimestamp = create_time_stamp
        message = datetimestamp + @options[:login] + SUB_ID
        tokenCode = sign_message(@options[:pem], @options[:password], message)

        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!
        xml.tag! 'DirectoryReq', 'xmlns' => 'http://www.idealdesk.com/Message', 'version' => API_VERSION do
          xml.tag! 'createDateTimeStamp', datetimestamp
          xml.tag! 'Merchant' do
            xml.tag! 'merchantID', @options[:login]
            xml.tag! 'subID', SUB_ID
            xml.tag! 'authentication', AUTHENTICATION_TYPE
            xml.tag! 'token', token
            xml.tag! 'tokenCode', tokenCode
          end
        end
        xml.target!
      end

      def commit(request)
        raw_response = ssl_post(url, request)
        response = Hash.from_xml(raw_response.to_s)
        response_type = response.keys[0]

        case response_type
          when 'AcquirerTrxRes', 'DirectoryRes'
            success = true
          when 'ErrorRes'
            success = false
          when 'AcquirerStatusRes'
            raise SecurityError, "Message verification failed.", caller unless status_response_verified?(response)
            success = (response['AcquirerStatusRes']['Transaction']['status'] == 'Success')
          else
            raise ArgumentError, "Unknown response type.", caller
        end

        return IdealResponse.new(success, response.keys[0], response, :test => test?)
      end

      def create_fingerprint(cert_file)
        cert_data   = OpenSSL::X509::Certificate.new(cert_file).to_s
        cert_data   = cert_data.sub(/-----BEGIN CERTIFICATE-----/, '')
        cert_data   = cert_data.sub(/-----END CERTIFICATE-----/, '')
        fingerprint = Base64.decode64(cert_data)
        fingerprint = Digest::SHA1.hexdigest(fingerprint)
        return fingerprint.upcase
      end

      def sign_message(private_key_data, password, data)
        private_key  = OpenSSL::PKey::RSA.new(private_key_data, password)
        signature = private_key.sign(OpenSSL::Digest::SHA1.new, data.gsub('\s', ''))
        return Base64.encode64(signature).gsub(/\n/, '')
      end

      def verify_message(cert_file, data, signature)
        public_key = OpenSSL::X509::Certificate.new(cert_file).public_key
        return public_key.verify(OpenSSL::Digest::SHA1.new, Base64.decode64(signature), data)
      end

      def status_response_verified?(response)
        transaction = response['AcquirerStatusRes']['Transaction']
        message = response['AcquirerStatusRes']['createDateTimeStamp'] + transaction['transactionID' ] + transaction['status']
        message << transaction['consumerAccountNumber'].to_s
        verify_message(server_pem, message, response['AcquirerStatusRes']['Signature']['signatureValue'])
      end

      def create_time_stamp
        Time.now.gmtime.strftime('%Y-%m-%dT%H:%M:%S.000Z')
      end
    end
  end
end
