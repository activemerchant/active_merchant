require File.dirname(__FILE__) + '/hps/infrastructure/hps_exception_mapper'
require File.dirname(__FILE__) + '/hps/infrastructure/sdk_codes'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HpsGateway < Gateway

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jbc, :diners_club]

      self.homepage_url = 'http://developer.heartlandpaymentsystems.com/SecureSubmit/'
      self.display_name = 'Heartland Payment Systems'

      self.money_format = :cents

      def initialize(options={})
        requires!(options, :secret_api_key)
        @secret_api_key = options[:secret_api_key]
        @developer_id = options[:developer_id] if options[:developer_id]
        @version_number = options[:version_number] if options[:version_number]
        @site_trace = options[:site_trace] if options[:site_trace]

        @exception_mapper = Hps::ExceptionMapper.new()
        super
      end
      
      def authorize(money, card_or_token, options={})
        request_multi_use_token = add_multi_use(options)

        if valid_amount?(money)
          xml = Builder::XmlMarkup.new
          xml.hps :Transaction do
            xml.hps :CreditAuth do
              xml.hps :Block1 do
                xml.hps :AllowDup, 'Y'
                xml.hps :Amt, amount(money)
                xml << add_customer_data(card_or_token,options)
                xml << add_details(options)
                xml.hps :CardData do
                  xml << add_payment(card_or_token)

                  xml.hps :TokenRequest, request_multi_use_token ? 'Y' : 'N'

                end
              end
            end
          end
          submit_auth_or_purchase 'CreditAuth', xml.target!, money
        else
          @exception_mapper.map_sdk_exception(Hps::SdkCodes.invalid_amount)
        end
      end

      def capture(money, transaction_id)

        xml = Builder::XmlMarkup.new
        xml.hps :Transaction do
          xml.hps :CreditAddToBatch do
            xml.hps :GatewayTxnId, transaction_id
            xml.hps :Amt, amount(money) if money
          end
        end

        response = do_transaction(xml.target!)
        if response.is_a? ActiveMerchant::Billing::Response
          return response
        end
        header = response['Header']

        return ActiveMerchant::Billing::Response.new(false, @exception_mapper.map_gateway_exception(transaction_id, header['GatewayRspCode'], header['GatewayRspMsg']).message ) unless header['GatewayRspCode'].eql? '0'

        get(transaction_id)
      end

      def get(transaction_id)

        if transaction_id.nil? or transaction_id == 0
          return ActiveMerchant::Billing::Response.new(false,@exception_mapper.map_sdk_exception(Hps::SdkCodes.invalid_transaction_id).message )
        end

        xml = Builder::XmlMarkup.new
        xml.hps :Transaction do
          xml.hps :ReportTxnDetail do
            xml.hps :TxnId, transaction_id
          end
        end
        submit_get xml.target!
      end

      def purchase(money, card_or_token, options={})
        if valid_amount?(money)
          request_multi_use_token = add_multi_use(options)

          xml = Builder::XmlMarkup.new
          xml.hps :Transaction do
            xml.hps :CreditSale do
              xml.hps :Block1 do
                xml.hps :AllowDup, 'Y'
                xml.hps :Amt, amount(money)
                xml << add_customer_data(card_or_token,options)
                xml << add_details(options)
                xml.hps :CardData do
                  xml << add_payment(card_or_token)
                  xml.hps :TokenRequest, request_multi_use_token ? 'Y' : 'N'
                end
              end
            end
          end
          submit_auth_or_purchase 'CreditSale', xml.target!, money
        else
          build_error_response @exception_mapper.map_sdk_exception(Hps::SdkCodes.invalid_amount).message
        end
      end

      def refund(money, transaction_id, options={})
        if valid_amount?(money)
          xml = Builder::XmlMarkup.new
          xml.hps :Transaction do
            xml.hps :CreditReturn do
              xml.hps :Block1 do
                xml.hps :AllowDup, 'Y'
                xml.hps :Amt, amount(money)
                xml.hps :GatewayTxnId, transaction_id
                xml << add_customer_data(transaction_id,options)
                xml << add_details(options)
              end
            end
          end
          submit_refund xml.target!
        else
          build_error_response @exception_mapper.map_sdk_exception(Hps::SdkCodes.invalid_amount).message
        end
      end

      def reverse_transaction(money, transaction_id, options={})
        if valid_amount?(money)
          xml = Builder::XmlMarkup.new
          xml.hps :Transaction do
            xml.hps :CreditReversal do
              xml.hps :Block1 do
                xml.hps :Amt, amount(money)
                xml.hps :GatewayTxnId, transaction_id
                xml << add_details(options)
              end
            end
          end
          submit_reverse xml.target!
        else
          build_error_response @exception_mapper.map_sdk_exception(Hps::SdkCodes.invalid_amount).message
        end
      end

      def void(transaction_id)
        xml = Builder::XmlMarkup.new
        xml.hps :Transaction do
          xml.hps :CreditVoid do
            xml.hps :GatewayTxnId, transaction_id
          end
        end

        submit_void xml.target!
      end

      def verify(card_or_token, options={})
        request_multi_use_token = add_multi_use(options)
        
        xml = Builder::XmlMarkup.new
        xml.hps :Transaction do
          xml.hps :CreditAccountVerify do
            xml.hps :Block1 do
              xml << add_customer_data(card_or_token,options)
              xml.hps :CardData do
                xml << add_payment(card_or_token)
                xml.hps :TokenRequest, request_multi_use_token ? 'Y' : 'N'
              end
            end
          end
        end

        submit_verify(xml.target!)
      end

      private

      def add_customer_data(card_or_token,options)
        xml = Builder::XmlMarkup.new
        if card_or_token.is_a? Billing::CreditCard
          billing_address = options[:billing_address] || options[:address]

          xml.hps :CardHolderData do
            xml.hps :CardHolderFirstName, card_or_token.first_name
            xml.hps :CardHolderLastName, card_or_token.last_name
            xml.hps :CardHolderEmail, options[:email] if options[:email]
            xml.hps :CardHolderPhone, options[:phone] if options[:phone]
            xml.hps :CardHolderAddr, billing_address[:address1] if billing_address[:address1]
            xml.hps :CardHolderCity, billing_address[:city] if billing_address[:city]
            xml.hps :CardHolderState, billing_address[:state] if billing_address[:state]
            xml.hps :CardHolderZip, billing_address[:zip] if billing_address[:zip]
          end
        end

        xml.target!
      end

      def add_payment(card_or_token)
        xml = Builder::XmlMarkup.new
        if card_or_token.is_a? Billing::CreditCard
          xml.hps :ManualEntry do
            xml.hps :CardNbr, card_or_token.number
            xml.hps :ExpMonth, card_or_token.month
            xml.hps :ExpYear, card_or_token.year
            xml.hps :CVV2, card_or_token.verification_value
            xml.hps :CardPresent, 'N'
            xml.hps :ReaderPresent, 'N'
          end

        else
          xml.hps :TokenData do
            xml.hps :TokenValue, card_or_token
          end
        end

        xml.target!
      end

      def add_details(options={})
        xml = Builder::XmlMarkup.new
        xml.hps :AdditionalTxnFields do
          xml.hps :Description, options[:description] if options[:description]
          xml.hps :InvoiceNbr, options[:order_id] if options[:order_id]
          xml.hps :CustomerID, options[:customer_id] if options[:customer_id]
        end
        xml.target!
      end

      def add_multi_use(options)
        multi_use = false
        multi_use = options[:request_multi_use_token] if options[:request_multi_use_token]
        multi_use
      end

      def valid_amount?(money)
        if money.nil? or money <= 0
          false
        end
        true
      end

      def submit_auth_or_purchase(action, xml, money)
        response = do_transaction(xml)

        if response.is_a? ActiveMerchant::Billing::Response
          response
        else
          header = response['Header']

          if successful?(response)
            transaction = response['Transaction'][action]

            if header['GatewayRspCode'].eql?('30') || !header['GatewayRspCode'].eql?('0')
              build_error_response process_charge_gateway_response(header['GatewayRspCode'], header['GatewayRspMsg'], header['GatewayTxnId'],money)
            elsif ! transaction['RspCode'].eql? '00'
              transaction = response['Transaction'][action]
              build_error_response process_charge_issuer_response(transaction['RspCode'],transaction['RspText'],header['GatewayTxnId'], money)
            else
              build_response(header,transaction, response)
            end
          else
            build_error_response(@exception_mapper.map_gateway_exception(header['GatewayTxnId'],header['GatewayRspCode'], header['GatewayRspMsg']))
          end
        end

      end

      def submit_get(xml)

        response = do_transaction(xml)

        if response.is_a? ActiveMerchant::Billing::Response
          response
        else
          transaction = response['Transaction']['ReportTxnDetail']

          header = response['Header']
          result = {
              'CardType' => transaction['Data']['CardType'],
              'CVVRsltCode' => transaction['Data']['CVVRsltCode'],
              'RspCode' => transaction['Data']['RspCode'],
              'RspText' => transaction['Data']['RspText'],
              'AVSRsltCode' => transaction['Data']['AVSRsltCode'],
              'AVSRsltText' => transaction['Data']['AVSRsltText'],
          }

          header_response_code = response['Header']['GatewayRspCode']
          data_response_code = transaction['Data']['RspCode']

          if header_response_code != '0' or data_response_code != '00'
            exception = Exception.new('Unknown Error')
            if header_response_code != '0'
              message = response['Header']['GatewayRspMsg']
              exception = @exception_mapper.map_gateway_exception(transaction['GatewayTxnId'], header_response_code, message)
            end

            if data_response_code != '0'
              message = transaction['Data']['RspText']
              exception = @exception_mapper.map_issuer_exception(transaction_id, data_response_code, message)
            end

            build_error_response(exception.message)

          else
            build_response(header,result, response)
          end
        end

      end

      def submit_refund(xml)
        response = do_transaction(xml)

        if response.is_a? ActiveMerchant::Billing::Response
          response
        else
          header = response['Header']

          if successful?(response)
            transaction ={
                'RspCode' => '00',
                'RspText' => ''
            }
            build_response(header,transaction,response)
          else
            build_error_response( @exception_mapper.map_gateway_exception(header['GatewayTxnId'], header['GatewayRspCode'], header['GatewayRspMsg']) )
          end
        end

      end

      def submit_reverse(xml)
        response = do_transaction(xml)

        if response.is_a? ActiveMerchant::Billing::Response
          response
        else
          header = response['Header']

          if successful?( response)
            transaction ={
                :RspCode => '00',
                :RspText => ''
            }
            build_response(header,transaction,response)
          else
            build_error_response( @exception_mapper.map_gateway_exception(header['GatewayTxnId'], header['GatewayRspCode'], header['GatewayRspMsg']) )
          end
        end

      end

      def submit_verify(transaction)
        response = do_transaction(transaction)
        if response.is_a? ActiveMerchant::Billing::Response
          response
        else
          header = response['Header']

          if successful?(response)
            transaction = response['Transaction']['CreditAccountVerify']
            result = {
                'CardType' => transaction['CardType'],
                'CVVRsltCode' => transaction['CVVRsltCode'],
                'RspCode' => transaction['RspCode'],
                'RspText' => transaction['RspText'],
                'AVSRsltCode' => transaction['AVSRsltCode'],
                'AVSRsltText' => transaction['AVSRsltText'],
            }

            if [ '85', '00' ].include? result['RspCode'] == false
              build_error_response @exception_mapper.map_issuer_exception(header['GatewayTxnId'], result['RspCode'], result['RspText'])
            else
              build_response header,result,response
            end
          else
            build_error_response @exception_mapper.map_gateway_exception(header['GatewayTxnId'], header['GatewayRspCode'], header['GatewayRspMsg'])
          end
        end
      end

      def submit_void(xml)
        response = do_transaction(xml)

        if response.is_a? ActiveMerchant::Billing::Response
          response
        else
          header = response['Header']

          if successful?(response)
            transaction ={
                'RspCode' => '00',
                'RspText' => ''
            }
            build_response(header,transaction,response)
          else
            build_error_response( @exception_mapper.map_gateway_exception(header['GatewayTxnId'], header['GatewayRspCode'], header['GatewayRspMsg']) )
          end
        end

      end
      def build_response( header, transaction, response)
        response = {
            :card_type => (transaction['CardType'] if transaction['CardType'] ) ,
            :response_code => (transaction['RspCode'] if transaction['RspCode']),
            :response_text => (transaction['RspText'] if transaction['RspText'] ),
            :transaction_header => header,
            :transaction_id => (header['GatewayTxnId'] if header['GatewayTxnId'] ),
            :token_data => {
                :response_message => (header['TokenData']['TokenRspMsg'] if (header['TokenData'] && header['TokenData']['TokenRspMsg']) ),
                :token_value =>(header['TokenData']['TokenValue'] if (header['TokenData'] && header['TokenData']['TokenValue']) ),
            },
            :full_response => response
        }
        options = {
           :test => test?,
           :authorization => authorization_from(transaction),
           :avs_result => {
               :code => (transaction['AVSRsltCode'] if transaction['AVSRsltCode'] ),
               :message => (transaction['AVSRsltText'] if transaction['AVSRsltText'] )
           },
           :cvv_result => (transaction['CVVRsltCode'] if transaction['CVVRsltCode'] )
        }
        ActiveMerchant::Billing::Response.new(true, message_from(header), response, options)
      end

      def build_error_response(exception)

        ActiveMerchant::Billing::Response.new(false,exception.message)
      end

      def successful?(response)
        response['Header']['GatewayRspCode'].eql? '0'
      end

      def message_from(header)
        header['GatewayRspMsg']
      end

      def authorization_from(response)
        response['AuthCode']
      end

      def do_transaction(transaction)

        if configuration_invalid?
          return build_error_response(@exception_mapper.map_sdk_exception(Hps::SdkCodes.unable_to_process_transaction))
        end

        xml = Builder::XmlMarkup.new
        xml.instruct!(:xml, :encoding => 'UTF-8')
        xml.SOAP :Envelope, {
            'xmlns:SOAP' => 'http://schemas.xmlsoap.org/soap/envelope/',
            'xmlns:hps' => 'http://Hps.Exchange.PosGateway' } do
          xml.SOAP :Body do
            xml.hps :PosRequest do
              xml.hps 'Ver1.0'.to_sym do
                xml.hps :Header do
                  xml.hps :SecretAPIKey, @secret_api_key
                  xml.hps :DeveloperID, @developer_id unless @developer_id.nil?
                  xml.hps :VersionNbr, @version_number unless @version_number.nil?
                  xml.hps :SiteTrace, @site_trace unless @site_trace.nil?
                end

                xml << transaction

              end
            end
          end
        end

        begin

          uri = URI.parse(gateway_url_for_key)
          http = Net::HTTP.new uri.host, uri.port
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          data = xml.target!

          response = ssl_post(gateway_url_for_key, data, 'Content-type' => 'text/xml')
          soap_hash = Hash.from_xml(response)
          # NOTE: Peel away the layers and return only the PosRespose
          soap_hash['Envelope']['Body']['PosResponse']['Ver1.0']

        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, ResponseError => e

          return build_error_response(@exception_mapper.map_sdk_exception(Hps::SdkCodes.unable_to_process_transaction, e))
        end

      end

      def configuration_invalid?
        @secret_api_key.nil? || @secret_api_key.eql?('')
      end

      def gateway_url_for_key
        gateway_url = 'https://posgateway.secureexchange.net/Hps.Exchange.PosGateway/PosGatewayService.asmx?wsdl'

        if @secret_api_key.include? '_cert_'
          gateway_url = 'https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway/PosGatewayService.asmx?wsdl'
        end
        gateway_url
      end

      def test?
        if @secret_api_key.include? '_cert_'
          true
        else
          false
        end
      end
      
      def process_charge_gateway_response(response_code, response_text, transaction_id, money)
        if response_code.eql? '30'

          begin

            reverse_transaction(money, transaction_id)

          rescue => e
            return @exception_mapper.map_sdk_exception(Hps::SdkCodes.reversal_error_after_gateway_timeout, e)
          end

        end

        @exception_mapper.map_gateway_exception(transaction_id, response_code, response_text)
      end

      def process_charge_issuer_response(response_code, response_text, transaction_id, money)

        if response_code.eql? '91'

          begin

            reverse_transaction(money, transaction_id)

          rescue => e
            @exception_mapper.map_sdk_exception(Hps::SdkCodes.reversal_error_after_issuer_timeout, e)
          end

          @exception_mapper.map_sdk_exception(Hps::SdkCodes.processing_error)

        elsif !response_code.eql? "00"

          @exception_mapper.map_issuer_exception(transaction_id, response_code, response_text)

        end

      end

    end
  end
end
