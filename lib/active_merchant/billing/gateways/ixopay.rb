require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IxopayGateway < Gateway
      self.test_url = 'https://secure.ixopay.com/transaction'
      self.live_url = 'https://secure.ixopay.com/transaction'

      self.supported_countries = %w(AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW)
      self.default_currency = 'EUR'
      self.currencies_with_three_decimal_places = %w(BHD IQD JOD KWD LWD OMR TND)
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb maestro]

      self.homepage_url = 'https://www.ixopay.com'
      self.display_name = 'Ixopay'

      def initialize(options={})
        requires!(options, :username, :password, :secret, :api_key)
        @secret = options[:secret]
        super
      end

      def purchase(money, payment_method, options={})
        request = build_xml_request do |xml|
          add_card_data(xml, payment_method)
          add_debit(xml, money, options)
        end

        commit(request)
      end

      def authorize(money, payment_method, options={})
        request = build_xml_request do |xml|
          add_card_data(xml, payment_method)
          add_preauth(xml, money, options)
        end

        commit(request)
      end

      def capture(money, authorization, options={})
        request = build_xml_request do |xml|
          add_capture(xml, money, authorization, options)
        end

        commit(request)
      end

      def refund(money, authorization, options={})
        request = build_xml_request do |xml|
          add_refund(xml, money, authorization, options)
        end

        commit(request)
      end

      def void(authorization, options={})
        request = build_xml_request do |xml|
          add_void(xml, authorization)
        end

        commit(request)
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
        clean_transcript = remove_invalid_utf_8_byte_sequences(transcript)

        clean_transcript.
          gsub(%r((Authorization: Gateway )(.*)(:)), '\1[FILTERED]\3').
          gsub(%r((<password>)(.*)(</password>)), '\1[FILTERED]\3').
          gsub(%r((<pan>)(.*)(</pan>)), '\1[FILTERED]\3').
          gsub(%r((<cvv>)\d+(</cvv>)), '\1[FILTERED]\2')
      end

      private

      def remove_invalid_utf_8_byte_sequences(text)
        text.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      end

      def headers(xml)
        timestamp = Time.now.httpdate
        signature = generate_signature('POST', xml, timestamp)

        {
          'Authorization' => "Gateway #{options[:api_key]}:#{signature}",
          'Date' => timestamp,
          'Content-Type' => 'text/xml; charset=utf-8'
        }
      end

      def generate_signature(http_method, xml, timestamp)
        content_type = 'text/xml; charset=utf-8'
        message = "#{http_method}\n#{Digest::MD5.hexdigest(xml)}\n#{content_type}\n#{timestamp}\n\n/transaction"
        digest = OpenSSL::Digest.new('sha512')
        hmac = OpenSSL::HMAC.digest(digest, @secret, message)

        Base64.encode64(hmac).delete("\n")
      end

      def parse(body)
        xml = Nokogiri::XML(body)
        response = Hash.from_xml(xml.to_s)['result']

        response.deep_transform_keys(&:underscore).transform_keys(&:to_sym)
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.transactionWithCard 'xmlns' => 'http://secure.ixopay.com/Schema/V2/TransactionWithCard' do
            xml.username @options[:username]
            xml.password Digest::SHA1.hexdigest(@options[:password])
            yield(xml)
          end
        end

        builder.to_xml
      end

      def add_card_data(xml, payment_method)
        xml.cardData do
          xml.cardHolder      payment_method.name
          xml.pan             payment_method.number
          xml.cvv             payment_method.verification_value
          xml.expirationMonth format(payment_method.month, :two_digits)
          xml.expirationYear  format(payment_method.year, :four_digits)
        end
      end

      def add_debit(xml, money, options)
        currency    = options[:currency] || currency(money)
        description = options[:description].blank? ? 'Purchase' : options[:description]

        xml.debit do
          xml.transactionId new_transaction_id

          add_customer_data(xml, options)
          add_extra_data(xml, options[:extra_data]) if options[:extra_data]

          xml.amount      localized_amount(money, currency)
          xml.currency    currency
          xml.description description
          xml.callbackUrl(options[:callback_url])
          add_stored_credentials(xml, options)
        end
      end

      def add_preauth(xml, money, options)
        description  = options[:description].blank? ? 'Preauthorize' : options[:description]
        currency     = options[:currency] || currency(money)
        callback_url = options[:callback_url]

        xml.preauthorize do
          xml.transactionId new_transaction_id

          add_customer_data(xml, options)
          add_extra_data(xml, options[:extra_data]) if options[:extra_data]

          xml.amount      localized_amount(money, currency)
          xml.currency    currency
          xml.description description
          xml.callbackUrl callback_url
          add_stored_credentials(xml, options)
        end
      end

      def add_refund(xml, money, authorization, options)
        currency = options[:currency] || currency(money)

        xml.refund do
          xml.transactionId new_transaction_id
          add_extra_data(xml, options[:extra_data]) if options[:extra_data]
          xml.referenceTransactionId authorization&.split('|')&.first
          xml.amount                 localized_amount(money, currency)
          xml.currency               currency
        end
      end

      def add_void(xml, authorization)
        xml.void do
          xml.transactionId new_transaction_id
          add_extra_data(xml, options[:extra_data]) if options[:extra_data]
          xml.referenceTransactionId authorization&.split('|')&.first
        end
      end

      def add_capture(xml, money, authorization, options)
        currency = options[:currency] || currency(money)

        xml.capture_ do
          xml.transactionId new_transaction_id
          add_extra_data(xml, options[:extra_data]) if options[:extra_data]
          xml.referenceTransactionId authorization&.split('|')&.first
          xml.amount                 localized_amount(money, currency)
          xml.currency               currency
        end
      end

      def add_customer_data(xml, options)
        # Ixopay returns an error if the elements are not added in the order used here.
        xml.customer do
          add_billing_address(xml,  options[:billing_address])  if options[:billing_address]
          add_shipping_address(xml, options[:shipping_address]) if options[:shipping_address]

          xml.company options[:billing_address][:company] if options.dig(:billing_address, :company)
          xml.email options[:email]
          xml.ipAddress(options[:ip] || '127.0.0.1')
        end
      end

      def add_billing_address(xml, address)
        if address[:name]
          xml.firstName split_names(address[:name])[0]
          xml.lastName  split_names(address[:name])[1]
        end

        xml.billingAddress1 address[:address1]
        xml.billingAddress2 address[:address2]
        xml.billingCity     address[:city]
        xml.billingPostcode address[:zip]
        xml.billingState    address[:state]
        xml.billingCountry  address[:country]
        xml.billingPhone    address[:phone]
      end

      def add_shipping_address(xml, address)
        if address[:name]
          xml.shippingFirstName split_names(address[:name])[0]
          xml.shippingLastName  split_names(address[:name])[1]
        end

        xml.shippingCompany   address[:company]
        xml.shippingAddress1  address[:address1]
        xml.shippingAddress2  address[:address2]
        xml.shippingCity      address[:city]
        xml.shippingPostcode  address[:zip]
        xml.shippingState     address[:state]
        xml.shippingCountry   address[:country]
        xml.shippingPhone     address[:phone]
      end

      def new_transaction_id
        SecureRandom.uuid
      end

      # Ixopay does not pass any parameters for cardholder/merchant initiated.
      # Ixopay also doesn't support installment transactions, only recurring
      # ("RECURRING") and unscheduled ("CARDONFILE").
      #
      # Furthermore, Ixopay is slightly unusual in its application of stored
      # credentials in that the gateway does not return a true
      # network_transaction_id that can be sent on subsequent transactions.
      def add_stored_credentials(xml, options)
        return unless stored_credential = options[:stored_credential]

        if stored_credential[:initial_transaction]
          xml.transactionIndicator 'INITIAL'
        elsif stored_credential[:reason_type] == 'recurring'
          xml.transactionIndicator 'RECURRING'
        elsif stored_credential[:reason_type] == 'unscheduled'
          xml.transactionIndicator 'CARDONFILE'
        end
      end

      def add_extra_data(xml, extra_data)
        extra_data.each do |k, v|
          xml.extraData(v, key: k)
        end
      end

      def commit(request)
        url = (test? ? test_url : live_url)

        # ssl_post raises an exception for any non-2xx HTTP status from the gateway
        response =
          begin
            parse(ssl_post(url, request, headers(request)))
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

      def success_from(response)
        response[:success] == 'true'
      end

      def message_from(response)
        response.dig(:errors, 'error', 'message') || response[:return_type]
      end

      def authorization_from(response)
        response[:reference_id] ? "#{response[:reference_id]}|#{response[:purchase_id]}" : nil
      end

      def error_code_from(response)
        response.dig(:errors, 'error', 'code') unless success_from(response)
      end
    end
  end
end
