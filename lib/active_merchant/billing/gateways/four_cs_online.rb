module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FourCsOnlineGateway < Gateway
      self.test_url = 'https://merchants.4csonline.com/DevTranSvcs/Ssis.asmx'
      self.live_url = 'https://merchants.4csonline.com/TranSvcs/Ssis.asmx'

      self.supported_countries = ['MS']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master]

      self.money_format = :dollars

      self.homepage_url = 'https://www.4csonline.com/'
      self.display_name = '4CS'

      def initialize(options = {})
        requires!(options, :merchant_key)
        super
      end

      def purchase(money, payment, options = {})
        soap = do_authorization_and_post(money, payment, options)
        commit('AuthAndPost', soap)
      end

      def authorize(money, payment, options = {})
        soap = do_authorization(money, payment, options)
        commit('AuthOnly', soap)
      end

      private

      def do_authorization(money, card, options)
        build_soap do |soap|
          add_credentials(soap, options)
          add_transaction_type(soap, 'AuthOnly')
          add_order_info(soap, money, options)
          add_customer_data(soap, card, options)
          add_address(soap, options)
          add_payment(soap, card)
        end
      end

      def do_authorization_and_post(money, card, options)
        build_soap do |soap|
          add_credentials(soap, options)
          add_transaction_type(soap, 'AuthAndPost')
          add_order_info(soap, money, options)
          add_customer_data(soap, card, options)
          add_address(soap, options)
          add_payment(soap, card)
        end
      end

      def add_credentials(soap, options)
        soap.tag!('MerchantKey', @options[:merchant_key].to_s)
      end

      def add_transaction_type(soap, transaction_type)
        soap.tag!('TranType', transaction_type)
      end

      def add_order_info(soap, money, options)
        soap.tag!('Amount', amount(money).to_s)
        soap.tag!('Currency', (options[:currency] || currency(money).to_s))
        soap.tag!('Invoice', options[:invoice].to_s)
        soap.tag!('TranId', options[:transaction_id].to_s)
      end

      def add_customer_data(soap, card, options)
        soap.tag!('CardholderName', card.name)
      end

      def add_address(soap, options)
        address = options[:billing_address] || options[:address]
        if address.present?
          address.delete(:name)
          address.delete(:company)
          address.delete(:phone)
          address.delete(:fax)
          soap.tag!('Address', address.values.join(', '))
        end
      end

      def add_payment(soap, card)
        month = card.month.to_s.rjust(2, '0')
        year = card.year.to_s[-2, 2]

        soap.tag!('CardNumber', card.number.to_s)
        soap.tag!('ExpiryMMYY', "#{month}#{year}")
        soap.tag!('VerificationValue', card.verification_value.to_s)
      end

      def parse(response, action)
        result = {}
        document = REXML::Document.new(response)
        response_element = document.root.get_elements('//response').first
        response_element.elements.each do |element|
          result[element.name.underscore] = element.text
        end
        result
      end

      def commit(soap_action, soap)
        headers = {
          'Content-Type' => 'text/xml; charset=utf-8'
        }

        response_string = ssl_post(test? ? self.test_url : self.live_url, soap, headers)
        response = parse(response_string, soap_action)

        return Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def build_soap
        retval = Builder::XmlMarkup.new(indent: 2)
        retval.instruct!(:xml, version: '1.0', encoding: 'utf-8')
        retval.tag!('soap:Envelope', {
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
        }) do
          retval.tag!('soap:Body') do
            retval.tag!('SSISProcessTransaction', { 'xmlns' => 'http://equament.com/Schemas/Fmx/ssis' }) do
              retval.tag!('request') do
                yield retval
              end
            end
          end
        end
        retval.target!
      end

      def success_from(response)
        response['financial_result_code'] == 'Approved'
      end

      def message_from(response)
        response['financial_result_code']
      end

      def authorization_from(response)
        response['approval_code']
      end

      def error_code_from(response)
        response['error_message'] unless success_from(response)
      end
    end
  end
end
