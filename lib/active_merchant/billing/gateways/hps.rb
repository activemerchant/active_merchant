require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HpsGateway < Gateway
      self.live_url = 'https://posgateway.secureexchange.net/Hps.Exchange.PosGateway/PosGatewayService.asmx?wsdl'
      self.test_url = 'https://posgateway.cert.secureexchange.net/Hps.Exchange.PosGateway/PosGatewayService.asmx?wsdl'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover jbc diners_club]

      self.homepage_url = 'http://developer.heartlandpaymentsystems.com/SecureSubmit/'
      self.display_name = 'Heartland Payment Systems'

      self.money_format = :dollars

      PAYMENT_DATA_SOURCE_MAPPING = {
        apple_pay:        'ApplePay',
        master:           'MasterCard 3DSecure',
        visa:             'Visa 3DSecure',
        american_express: 'AMEX 3DSecure',
        discover:         'Discover 3DSecure',
        android_pay:      'GooglePayApp',
        google_pay:       'GooglePayApp'
      }

      def initialize(options={})
        requires!(options, :secret_api_key)
        super
      end

      def authorize(money, card_or_token, options={})
        commit('CreditAuth') do |xml|
          add_amount(xml, money)
          add_allow_dup(xml)
          add_card_or_token_customer_data(xml, card_or_token, options)
          add_details(xml, options)
          add_descriptor_name(xml, options)
          add_card_or_token_payment(xml, card_or_token, options)
          add_three_d_secure(xml, card_or_token, options)
        end
      end

      def capture(money, transaction_id, options={})
        commit('CreditAddToBatch', transaction_id) do |xml|
          add_amount(xml, money)
          add_reference(xml, transaction_id)
        end
      end

      def purchase(money, payment_method, options={})
        if payment_method.is_a?(Check)
          commit_check_sale(money, payment_method, options)
        else
          commit_credit_sale(money, payment_method, options)
        end
      end

      def refund(money, transaction_id, options={})
        commit('CreditReturn') do |xml|
          add_amount(xml, money)
          add_allow_dup(xml)
          add_reference(xml, transaction_id)
          add_card_or_token_customer_data(xml, transaction_id, options)
          add_details(xml, options)
        end
      end

      def verify(card_or_token, options={})
        commit('CreditAccountVerify') do |xml|
          add_card_or_token_customer_data(xml, card_or_token, options)
          add_descriptor_name(xml, options)
          add_card_or_token_payment(xml, card_or_token, options)
        end
      end

      def void(transaction_id, options={})
        if options[:check_void]
          commit('CheckVoid') do |xml|
            add_reference(xml, transaction_id)
          end
        else
          commit('CreditVoid') do |xml|
            add_reference(xml, transaction_id)
          end
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<hps:CardNbr>)[^<]*(<\/hps:CardNbr>))i, '\1[FILTERED]\2').
          gsub(%r((<hps:CVV2>)[^<]*(<\/hps:CVV2>))i, '\1[FILTERED]\2').
          gsub(%r((<hps:SecretAPIKey>)[^<]*(<\/hps:SecretAPIKey>))i, '\1[FILTERED]\2').
          gsub(%r((<hps:PaymentData>)[^<]*(<\/hps:PaymentData>))i, '\1[FILTERED]\2').
          gsub(%r((<hps:RoutingNumber>)[^<]*(<\/hps:RoutingNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<hps:AccountNumber>)[^<]*(<\/hps:AccountNumber>))i, '\1[FILTERED]\2')
      end

      private

      def commit_check_sale(money, check, options)
        commit('CheckSale') do |xml|
          add_check_payment(xml, check, options)
          add_amount(xml, money)
          add_sec_code(xml, options)
          add_check_customer_data(xml, check, options)
          add_details(xml, options)
        end
      end

      def commit_credit_sale(money, card_or_token, options)
        commit('CreditSale') do |xml|
          add_amount(xml, money)
          add_allow_dup(xml)
          add_card_or_token_customer_data(xml, card_or_token, options)
          add_details(xml, options)
          add_descriptor_name(xml, options)
          add_card_or_token_payment(xml, card_or_token, options)
          add_three_d_secure(xml, card_or_token, options)
        end
      end

      def add_reference(xml, transaction_id)
        reference = transaction_id.to_s.include?('|') ? transaction_id.split('|').first : transaction_id
        xml.hps :GatewayTxnId, reference
      end

      def add_amount(xml, money)
        xml.hps :Amt, amount(money) if money
      end

      def add_card_or_token_customer_data(xml, credit_card, options)
        xml.hps :CardHolderData do
          if credit_card.respond_to?(:number)
            xml.hps :CardHolderFirstName, credit_card.first_name if credit_card.first_name
            xml.hps :CardHolderLastName, credit_card.last_name if credit_card.last_name
          end

          xml.hps :CardHolderEmail, options[:email] if options[:email]
          xml.hps :CardHolderPhone, options[:phone] if options[:phone]

          if (billing_address = (options[:billing_address] || options[:address]))
            xml.hps :CardHolderAddr, billing_address[:address1] if billing_address[:address1]
            xml.hps :CardHolderCity, billing_address[:city] if billing_address[:city]
            xml.hps :CardHolderState, billing_address[:state] if billing_address[:state]
            xml.hps :CardHolderZip, billing_address[:zip] if billing_address[:zip]
          end
        end
      end

      def add_check_customer_data(xml, check, options)
        xml.hps :ConsumerInfo do
          xml.hps :FirstName, check.first_name
          xml.hps :LastName, check.last_name
          xml.hps :CheckName, options[:company_name] if options[:company_name]
        end
      end

      def add_card_or_token_payment(xml, card_or_token, options)
        xml.hps :CardData do
          if card_or_token.respond_to?(:number)
            if card_or_token.track_data
              xml.tag!('hps:TrackData', 'method' => 'swipe') do
                xml.text! card_or_token.track_data
              end
              if options[:encryption_type]
                xml.hps :EncryptionData do
                  xml.hps :Version, options[:encryption_type]
                  if options[:encryption_type] == '02'
                    xml.hps :EncryptedTrackNumber, options[:encrypted_track_number]
                    xml.hps :KTB, options[:ktb]
                  end
                end
              end
            else
              xml.hps :ManualEntry do
                xml.hps :CardNbr, card_or_token.number
                xml.hps :ExpMonth, card_or_token.month
                xml.hps :ExpYear, card_or_token.year
                xml.hps :CVV2, card_or_token.verification_value if card_or_token.verification_value
                xml.hps :CardPresent, 'N'
                xml.hps :ReaderPresent, 'N'
              end
            end
          else
            xml.hps :TokenData do
              xml.hps :TokenValue, card_or_token
            end
          end
          xml.hps :TokenRequest, (options[:store] ? 'Y' : 'N')
        end
      end

      def add_check_payment(xml, check, options)
        xml.hps :CheckAction, 'SALE'
        xml.hps :AccountInfo do
          xml.hps :RoutingNumber, check.routing_number
          xml.hps :AccountNumber, check.account_number
          xml.hps :CheckNumber, check.number
          xml.hps :AccountType, check.account_type&.upcase
        end
        xml.hps :CheckType, check.account_holder_type&.upcase
      end

      def add_details(xml, options)
        xml.hps :AdditionalTxnFields do
          xml.hps :Description, options[:description] if options[:description]
          xml.hps :InvoiceNbr, options[:order_id] if options[:order_id]
          xml.hps :CustomerID, options[:customer_id] if options[:customer_id]
        end
      end

      def add_sec_code(xml, options)
        xml.hps :SECCode, options[:sec_code] || 'WEB'
      end

      def add_allow_dup(xml)
        xml.hps :AllowDup, 'Y'
      end

      def add_descriptor_name(xml, options)
        xml.hps :TxnDescriptor, options[:descriptor_name] if options[:descriptor_name]
      end

      def add_three_d_secure(xml, card_or_token, options)
        if card_or_token.is_a?(NetworkTokenizationCreditCard)
          build_three_d_secure(xml, {
            source: card_or_token.source,
            cavv: card_or_token.payment_cryptogram,
            eci: card_or_token.eci,
            xid: card_or_token.transaction_id
          })
        elsif options[:three_d_secure]
          options[:three_d_secure][:source] ||= card_brand(card_or_token)
          build_three_d_secure(xml, options[:three_d_secure])
        end
      end

      def build_three_d_secure(xml, three_d_secure)
        # PaymentDataSource is required when supplying the SecureECommerce data group,
        # and the gateway currently only allows the values within the mapping
        return unless PAYMENT_DATA_SOURCE_MAPPING[three_d_secure[:source].to_sym]

        xml.hps :SecureECommerce do
          xml.hps :PaymentDataSource, PAYMENT_DATA_SOURCE_MAPPING[three_d_secure[:source].to_sym]
          xml.hps :TypeOfPaymentData, '3DSecure' # Only type currently supported
          xml.hps :PaymentData, three_d_secure[:cavv] if three_d_secure[:cavv]
          # the gateway only allows a single character for the ECI
          xml.hps :ECommerceIndicator, strip_leading_zero(three_d_secure[:eci]) if three_d_secure[:eci]
          xml.hps :XID, three_d_secure[:xid] if three_d_secure[:xid]
        end
      end

      def strip_leading_zero(value)
        return value unless value[0] == '0'

        value[1, 1]
      end

      def build_request(action)
        xml = Builder::XmlMarkup.new(encoding: 'UTF-8')
        xml.instruct!(:xml, encoding: 'UTF-8')
        xml.SOAP :Envelope, {
          'xmlns:SOAP' => 'http://schemas.xmlsoap.org/soap/envelope/',
          'xmlns:hps' => 'http://Hps.Exchange.PosGateway'
        } do
          xml.SOAP :Body do
            xml.hps :PosRequest do
              xml.hps 'Ver1.0'.to_sym do
                xml.hps :Header do
                  xml.hps :SecretAPIKey, @options[:secret_api_key]
                  xml.hps :DeveloperID, @options[:developer_id] if @options[:developer_id]
                  xml.hps :VersionNbr, @options[:version_number] if @options[:version_number]
                  xml.hps :SiteTrace, @options[:site_trace] if @options[:site_trace]
                end
                xml.hps :Transaction do
                  xml.hps action.to_sym do
                    if %w(CreditVoid CreditAddToBatch).include?(action)
                      yield(xml)
                    else
                      xml.hps :Block1 do
                        yield(xml)
                      end
                    end
                  end
                end
              end
            end
          end
        end
        xml.target!
      end

      def parse(raw)
        response = {}

        doc = Nokogiri::XML(raw)
        doc.remove_namespaces!
        if (header = doc.xpath('//Header').first)
          header.elements.each do |node|
            if node.elements.size == 0
              response[node.name] = node.text
            else
              node.elements.each do |childnode|
                response[childnode.name] = childnode.text
              end
            end
          end
        end
        if (transaction = doc.xpath('//Transaction/*[1]').first)
          transaction.elements.each do |node|
            response[node.name] = node.text
          end
        end
        if (fault = doc.xpath('//Fault/Reason/Text').first)
          response['Fault'] = fault.text
        end

        response
      end

      def commit(action, reference = nil, &request)
        data = build_request(action, &request)

        response =
          begin
            parse(ssl_post((test? ? test_url : live_url), data, 'Content-Type' => 'text/xml'))
          rescue ResponseError => e
            parse(e.response.body)
          end

        ActiveMerchant::Billing::Response.new(
          successful?(response),
          message_from(response),
          response,
          test: test?,
          authorization: authorization_from(response, reference),
          avs_result: {
            code: response['AVSRsltCode'],
            message: response['AVSRsltText']
          },
          cvv_result: response['CVVRsltCode']
        )
      end

      SUCCESSFUL_RESPONSE_CODES = %w(0 00 85)
      def successful?(response)
        (
          (response['GatewayRspCode'] == '0') &&
          ((SUCCESSFUL_RESPONSE_CODES.include? response['RspCode']) || !response['RspCode'])
        )
      end

      def message_from(response)
        if response['Fault']
          response['Fault']
        elsif response['GatewayRspCode'] == '0'
          if SUCCESSFUL_RESPONSE_CODES.include? response['RspCode']
            response['GatewayRspMsg']
          else
            issuer_message(response['RspCode'])
          end
        else
          (GATEWAY_MESSAGES[response['GatewayRspCode']] || response['GatewayRspMsg'])
        end
      end

      def authorization_from(response, reference)
        return [reference, response['GatewayTxnId']].join('|') if reference

        response['GatewayTxnId']
      end

      def test?
        @options[:secret_api_key]&.include?('_cert_')
      end

      ISSUER_MESSAGES = {
        '13' => 'Must be greater than or equal 0.',
        '14' => 'The card number is incorrect.',
        '54' => 'The card has expired.',
        '55' => 'The 4-digit pin is invalid.',
        '75' => 'Maximum number of pin retries exceeded.',
        '80' => 'Card expiration date is invalid.',
        '86' => "Can't verify card pin number."
      }
      def issuer_message(code)
        return 'The card was declined.' if %w(02 03 04 05 41 43 44 51 56 61 62 63 65 78).include?(code)
        return 'An error occurred while processing the card.' if %w(06 07 12 15 19 12 52 53 57 58 76 77 91 96 EC).include?(code)
        return "The card's security code is incorrect." if %w(EB N7).include?(code)

        ISSUER_MESSAGES[code]
      end

      GATEWAY_MESSAGES = {
        '-2' => 'Authentication error. Please double check your service configuration.',
        '12' => 'Invalid CPC data.',
        '13' => 'Invalid card data.',
        '14' => 'The card number is not a valid credit card number.',
        '30' => 'Gateway timed out.'
      }
    end
  end
end
