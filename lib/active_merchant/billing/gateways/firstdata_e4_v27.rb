module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstdataE4V27Gateway < Gateway
      self.test_url = 'https://api.demo.globalgatewaye4.firstdata.com/transaction/v28'
      self.live_url = 'https://api.globalgatewaye4.firstdata.com/transaction/v28'

      TRANSACTIONS = {
        sale:          '00',
        authorization: '01',
        verify:        '05',
        capture:       '32',
        void:          '33',
        credit:        '34',
        store:         '05'
      }

      SUCCESS = 'true'

      SENSITIVE_FIELDS = %i[cvdcode expiry_date card_number]

      BRANDS = {
        visa: 'Visa',
        master: 'Mastercard',
        american_express: 'American Express',
        jcb: 'JCB',
        discover: 'Discover'
      }

      DEFAULT_ECI = '07'

      self.supported_cardtypes = BRANDS.keys
      self.supported_countries = %w[CA US]
      self.default_currency = 'USD'
      self.homepage_url = 'http://www.firstdata.com'
      self.display_name = 'FirstData Global Gateway e4 v27'

      STANDARD_ERROR_CODE_MAPPING = {
        # Bank error codes: https://support.payeezy.com/hc/en-us/articles/203730509-First-Data-Global-Gateway-e4-Bank-Response-Codes
        '201' => STANDARD_ERROR_CODE[:incorrect_number],
        '531' => STANDARD_ERROR_CODE[:invalid_cvc],
        '503' => STANDARD_ERROR_CODE[:invalid_cvc],
        '811' => STANDARD_ERROR_CODE[:invalid_cvc],
        '605' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '522' => STANDARD_ERROR_CODE[:expired_card],
        '303' => STANDARD_ERROR_CODE[:card_declined],
        '530' => STANDARD_ERROR_CODE[:card_declined],
        '401' => STANDARD_ERROR_CODE[:call_issuer],
        '402' => STANDARD_ERROR_CODE[:call_issuer],
        '501' => STANDARD_ERROR_CODE[:pickup_card],
        # Ecommerce error codes: https://support.payeezy.com/hc/en-us/articles/203730499-eCommerce-Response-Codes-ETG-e4-Transaction-Gateway-Codes
        '22' => STANDARD_ERROR_CODE[:invalid_number],
        '25' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '31' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '44' => STANDARD_ERROR_CODE[:incorrect_zip],
        '42' => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options = {})
        requires!(options, :login, :password, :key_id, :hmac_key)
        @options = options

        super
      end

      def authorize(money, credit_card_or_store_authorization, options = {})
        commit(:authorization, build_sale_or_authorization_request(money, credit_card_or_store_authorization, options))
      end

      def purchase(money, credit_card_or_store_authorization, options = {})
        commit(:sale, build_sale_or_authorization_request(money, credit_card_or_store_authorization, options))
      end

      def capture(money, authorization, options = {})
        commit(:capture, build_capture_or_credit_request(money, authorization, options))
      end

      def void(authorization, options = {})
        commit(:void, build_capture_or_credit_request(money_from_authorization(authorization), authorization, options))
      end

      def refund(money, authorization, options = {})
        commit(:credit, build_capture_or_credit_request(money, authorization, options))
      end

      def verify(credit_card, options = {})
        commit(:verify, build_sale_or_authorization_request(0, credit_card, options))
      end

      # Tokenize a credit card with TransArmor
      #
      # The TransArmor token and other card data necessary for subsequent
      # transactions is stored in the response's +authorization+ attribute.
      # The authorization string may be passed to +authorize+ and +purchase+
      # instead of a +ActiveMerchant::Billing::CreditCard+ instance.
      #
      # TransArmor support must be explicitly activated on your gateway
      # account by FirstData. If your authorization string is empty, contact
      # FirstData support for account setup assistance.
      #
      # https://support.payeezy.com/hc/en-us/articles/203731189-TransArmor-Tokenization
      def store(credit_card, options = {})
        commit(:store, build_store_request(credit_card, options), credit_card)
      end

      def verify_credentials
        response = void('0')
        response.message != 'Unauthorized Request. Bad or missing credentials.'
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<Card_Number>).+(</Card_Number>)), '\1[FILTERED]\2').
          gsub(%r((<CVDCode>).+(</CVDCode>)), '\1[FILTERED]\2').
          gsub(%r((<Password>).+(</Password>))i, '\1[FILTERED]\2').
          gsub(%r((<CAVV>).+(</CAVV>)), '\1[FILTERED]\2').
          gsub(%r((CARD NUMBER\s+: )#+\d+), '\1[FILTERED]')
      end

      def supports_network_tokenization?
        true
      end

      private

      def build_request(action, body)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag! 'Transaction', xmlns: 'http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/encodedTypes' do
          add_credentials(xml)
          add_transaction_type(xml, action)
          xml << body
        end

        xml.target!
      end

      def build_sale_or_authorization_request(money, credit_card_or_store_authorization, options)
        xml = Builder::XmlMarkup.new

        add_amount(xml, money, options)

        if credit_card_or_store_authorization.is_a? String
          add_credit_card_token(xml, credit_card_or_store_authorization, options)
        else
          add_credit_card(xml, credit_card_or_store_authorization, options)
          add_stored_credentials(xml, credit_card_or_store_authorization, options)
        end

        add_address(xml, options)
        add_customer_data(xml, options)
        add_invoice(xml, options)
        add_tax_fields(xml, options)
        add_level_3(xml, options)

        xml.target!
      end

      def build_capture_or_credit_request(money, identification, options)
        xml = Builder::XmlMarkup.new

        add_identification(xml, identification)
        add_amount(xml, money, options)
        add_customer_data(xml, options)
        add_card_authentication_data(xml, options)

        xml.target!
      end

      def build_store_request(credit_card, options)
        xml = Builder::XmlMarkup.new

        add_credit_card(xml, credit_card, options)
        add_address(xml, options)
        add_customer_data(xml, options)

        xml.target!
      end

      def add_credentials(xml)
        xml.tag! 'ExactID', @options[:login]
        xml.tag! 'Password', @options[:password]
      end

      def add_transaction_type(xml, action)
        xml.tag! 'Transaction_Type', TRANSACTIONS[action]
      end

      def add_identification(xml, identification)
        authorization_num, transaction_tag, = identification.split(';')

        xml.tag! 'Authorization_Num', authorization_num
        xml.tag! 'Transaction_Tag', transaction_tag
      end

      def add_amount(xml, money, options)
        currency_code = options[:currency] || default_currency
        xml.tag! 'DollarAmount', localized_amount(money, currency_code)
        xml.tag! 'Currency', currency_code
      end

      def add_credit_card(xml, credit_card, options)
        if credit_card.respond_to?(:track_data) && credit_card.track_data.present?
          xml.tag! 'Track1', credit_card.track_data
          xml.tag! 'Ecommerce_Flag', 'R'
        else
          xml.tag! 'Card_Number', credit_card.number
          xml.tag! 'Expiry_Date', expdate(credit_card)
          xml.tag! 'CardHoldersName', credit_card.name
          xml.tag! 'CardType', card_type(credit_card.brand)
          xml.tag! 'WalletProviderID', options[:wallet_provider_id] if options[:wallet_provider_id]

          add_credit_card_eci(xml, credit_card, options)
          add_credit_card_verification_strings(xml, credit_card, options)
        end
      end

      def add_credit_card_eci(xml, credit_card, options)
        eci = if credit_card.is_a?(NetworkTokenizationCreditCard) && credit_card.source == :apple_pay && card_brand(credit_card) == 'discover'
                # Discover requires any Apple Pay transaction, regardless of in-app
                # or web, and regardless of the ECI contained in the PKPaymentToken,
                # to have an ECI value explicitly of 04.
                '04'
              else
                (credit_card.respond_to?(:eci) ? credit_card.eci : nil) || options[:eci] || DEFAULT_ECI
              end

        xml.tag! 'Ecommerce_Flag', /^[0-9]+$/.match?(eci.to_s) ? eci.to_s.rjust(2, '0') : eci
      end

      def add_credit_card_verification_strings(xml, credit_card, options)
        if credit_card.is_a?(NetworkTokenizationCreditCard)
          add_network_tokenization_credit_card(xml, credit_card)
        else
          if credit_card.verification_value?
            xml.tag! 'CVD_Presence_Ind', '1'
            xml.tag! 'CVDCode', credit_card.verification_value
          end

          add_card_authentication_data(xml, options)
        end
      end

      def add_network_tokenization_credit_card(xml, credit_card)
        case card_brand(credit_card).to_sym
        when :american_express
          cryptogram = Base64.decode64(credit_card.payment_cryptogram)
          xml.tag!('XID', Base64.encode64(cryptogram[20...40]))
          xml.tag!('CAVV', Base64.encode64(cryptogram[0...20]))
        else
          xml.tag!('XID', credit_card.transaction_id) if credit_card.transaction_id
          xml.tag!('CAVV', credit_card.payment_cryptogram)
        end
      end

      def add_card_authentication_data(xml, options)
        xml.tag! 'CAVV', options[:cavv]
        xml.tag! 'XID', options[:xid]
      end

      def add_credit_card_token(xml, store_authorization, options)
        params = store_authorization.split(';')
        credit_card = CreditCard.new(
          brand: params[1],
          first_name: params[2],
          last_name: params[3],
          month: params[4],
          year: params[5])

        xml.tag! 'TransarmorToken', params[0]
        xml.tag! 'Expiry_Date', expdate(credit_card)
        xml.tag! 'CardHoldersName', credit_card.name
        xml.tag! 'CardType', card_type(credit_card.brand)
        xml.tag! 'WalletProviderID', options[:wallet_provider_id] if options[:wallet_provider_id]
        add_card_authentication_data(xml, options)
      end

      def add_customer_data(xml, options)
        xml.tag! 'Customer_Ref', options[:customer] if options[:customer]
        xml.tag! 'Client_IP', options[:ip] if options[:ip]
        xml.tag! 'Client_Email', options[:email] if options[:email]
      end

      def add_address(xml, options)
        if (address = options[:billing_address] || options[:address])
          address = strip_line_breaks(address)

          xml.tag! 'Address' do
            xml.tag! 'Address1', address[:address1]
            xml.tag! 'Address2', address[:address2] if address[:address2]
            xml.tag! 'City', address[:city]
            xml.tag! 'State', address[:state]
            xml.tag! 'Zip', address[:zip]
            xml.tag! 'CountryCode', address[:country]
          end
          xml.tag! 'ZipCode', address[:zip]
        end
      end

      def strip_line_breaks(address)
        return unless address.is_a?(Hash)

        Hash[address.map { |k, s| [k, s&.tr("\r\n", ' ')&.strip] }]
      end

      def add_invoice(xml, options)
        xml.tag! 'Reference_No', options[:order_id]
        xml.tag! 'Reference_3',  options[:description] if options[:description]
      end

      def add_tax_fields(xml, options)
        xml.tag! 'Tax1Amount',  options[:tax1_amount] if options[:tax1_amount]
        xml.tag! 'Tax1Number',  options[:tax1_number] if options[:tax1_number]
      end

      def add_level_3(xml, options)
        xml.tag!('Level3') { |x| x << options[:level_3] } if options[:level_3]
      end

      def add_stored_credentials(xml, card, options)
        return unless options[:stored_credential]

        xml.tag! 'StoredCredentials' do
          xml.tag! 'Indicator', stored_credential_indicator(xml, card, options)
          if initiator = options.dig(:stored_credential, :initiator)
            xml.tag! 'Initiation', initiator == 'merchant' ? 'M' : 'C'
          end
          if reason_type = options.dig(:stored_credential, :reason_type)
            xml.tag! 'Schedule', reason_type == 'unscheduled' ? 'U' : 'S'
          end
          xml.tag! 'AuthorizationTypeOverride', options[:authorization_type_override] if options[:authorization_type_override]
          if network_transaction_id = options[:stored_credential][:network_transaction_id]
            xml.tag! 'TransactionId', network_transaction_id
          else
            xml.tag! 'TransactionId', 'new'
          end
          xml.tag! 'OriginalAmount', options[:original_amount] if options[:original_amount]
          xml.tag! 'ProtectbuyIndicator', options[:protectbuy_indicator] if options[:protectbuy_indicator]
        end
      end

      def stored_credential_indicator(xml, card, options)
        if card.brand == 'master' || options.dig(:stored_credential, :initial_transaction) == false
          'S'
        else
          '1'
        end
      end

      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def card_type(credit_card_brand)
        BRANDS[credit_card_brand.to_sym] if credit_card_brand
      end

      def commit(action, data, credit_card = nil)
        url = (test? ? self.test_url : self.live_url)
        request = build_request(action, data)
        begin
          response = parse(ssl_post(url, request, headers('POST', url, request)))
        rescue ResponseError => e
          response = parse_error(e.response)
        end

        Response.new(successful?(response), message_from(response), response,
          test: test?,
          authorization: successful?(response) ? response_authorization(action, response, credit_card) : '',
          avs_result: {code: response[:avs]},
          cvv_result: response[:cvv2],
          error_code: standard_error_code(response)
        )
      end

      def headers(method, url, request)
        content_type = 'application/xml'
        content_digest = Digest::SHA1.hexdigest(request)
        sending_time = Time.now.utc.iso8601
        payload = [method, content_type, content_digest, sending_time, url.split('.com')[1]].join("\n")
        hmac = OpenSSL::HMAC.digest('sha1', @options[:hmac_key], payload)
        encoded = Base64.strict_encode64(hmac)

        {
          'x-gge4-date' => sending_time,
          'x-gge4-content-sha1' => content_digest,
          'Authorization' => 'GGE4_API ' + @options[:key_id].to_s + ':' + encoded,
          'Accepts' => content_type,
          'Content-Type' => content_type
        }
      end

      def successful?(response)
        response[:transaction_approved] == SUCCESS
      end

      def response_authorization(action, response, credit_card)
        if action == :store
          store_authorization_from(response, credit_card)
        else
          authorization_from(response)
        end
      end

      def authorization_from(response)
        if response[:authorization_num] && response[:transaction_tag]
          [
            response[:authorization_num],
            response[:transaction_tag],
            (response[:dollar_amount].to_f * 100).round
          ].join(';')
        else
          ''
        end
      end

      def store_authorization_from(response, credit_card)
        if response[:transarmor_token].present?
          [
            response[:transarmor_token],
            credit_card.brand,
            credit_card.first_name,
            credit_card.last_name,
            credit_card.month,
            credit_card.year
          ].map { |value| value.to_s.tr(';', '') }.join(';')
        else
          raise StandardError, "TransArmor support is not enabled on your #{display_name} account"
        end
      end

      def money_from_authorization(auth)
        _, _, amount = auth.split(/;/, 3)
        amount.to_i
      end

      def message_from(response)
        if response[:faultcode] && response[:faultstring]
          response[:faultstring]
        elsif response[:error_number] && response[:error_number] != '0'
          response[:error_description]
        else
          result = (response[:exact_message] || '')
          result << " - #{response[:bank_message]}" if response[:bank_message].present?
          result
        end
      end

      def parse_error(error)
        {
          transaction_approved: 'false',
          error_number: error.code,
          error_description: error.body,
          ecommerce_error_code: error.body.gsub(/[^\d]/, '')
        }
      end

      def standard_error_code(response)
        STANDARD_ERROR_CODE_MAPPING[response[:bank_resp_code] || response[:ecommerce_error_code]]
      end

      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)

        if (root = REXML::XPath.first(xml, '//TransactionResult'))
          parse_elements(response, root)
        end

        SENSITIVE_FIELDS.each { |key| response.delete(key) }
        response
      end

      def parse_elements(response, root)
        root.elements.to_a.each do |node|
          if node.has_elements?
            parse_elements(response, node)
          else
            response[name_node(root, node)] = (node.text || '').strip
          end
        end
      end

      def name_node(root, node)
        parent = root.name unless root.name == 'TransactionResult'
        "#{parent}#{node.name}".gsub(/EXact/, 'Exact').underscore.to_sym
      end
    end
  end
end
