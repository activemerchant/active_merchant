module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstdataE4Gateway < Gateway
      # TransArmor support requires v11 or lower
      self.test_url = "https://api.demo.globalgatewaye4.firstdata.com/transaction/v11"
      self.live_url = "https://api.globalgatewaye4.firstdata.com/transaction/v11"

      TRANSACTIONS = {
        sale:          "00",
        authorization: "01",
        verify:        "05",
        capture:       "32",
        void:          "33",
        credit:        "34",
        store:         "05"
      }

      POST_HEADERS = {
        "Accepts" => "application/xml",
        "Content-Type" => "application/xml"
      }

      SUCCESS = "true"

      SENSITIVE_FIELDS = [:verification_str2, :expiry_date, :card_number]

      BRANDS = {
        :visa => 'Visa',
        :master => "Mastercard",
        :american_express => "American Express",
        :jcb => "JCB",
        :discover => "Discover"
      }

      E4_BRANDS = BRANDS.merge({:mastercard => "Mastercard"})

      DEFAULT_ECI = "07"

      self.supported_cardtypes = BRANDS.keys
      self.supported_countries = ["CA", "US"]
      self.default_currency = "USD"
      self.homepage_url = "http://www.firstdata.com"
      self.display_name = "FirstData Global Gateway e4"

      STANDARD_ERROR_CODE_MAPPING = {
      # Bank error codes: https://firstdata.zendesk.com/entries/471297-First-Data-Global-Gateway-e4-Bank-Response-Codes
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
      # Ecommerce error codes -- https://firstdata.zendesk.com/entries/451980-ecommerce-response-codes-etg-codes
        '22' => STANDARD_ERROR_CODE[:invalid_number],
        '25' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '31' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '44' => STANDARD_ERROR_CODE[:incorrect_zip],
        '42' => STANDARD_ERROR_CODE[:processing_error]
      }

      # Create a new FirstdataE4Gateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> --    The EXACT ID.  Also known as the Gateway ID.
      #                         (Found in your administration terminal settings)
      # * <tt>:password</tt> -- The terminal password (not your account password)
      def initialize(options = {})
        requires!(options, :login, :password)
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
      # === Example
      #
      #   # Generate token
      #   result = gateway.store(credit_card)
      #   if result.success?
      #     my_record.update_attributes(:authorization => result.authorization)
      #   end
      #
      #   # Use token
      #   result = gateway.purchase(1000, my_record.authorization)
      #
      # https://firstdata.zendesk.com/entries/21303361-transarmor-tokenization
      def store(credit_card, options = {})
        commit(:store, build_store_request(credit_card, options), credit_card)
      end

      def verify_credentials
        response = void("0")
        response.message != "Unauthorized Request. Bad or missing credentials."
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(%r((<Card_Number>).+(</Card_Number>)), '\1[FILTERED]\2')
          .gsub(%r((<VerificationStr2>).+(</VerificationStr2>)), '\1[FILTERED]\2')
          .gsub(%r((<CAVV>).+(</CAVV>)), '\1[FILTERED]\2')
      end

      def supports_network_tokenization?
        true
      end

      private

      def build_request(action, body)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag! "Transaction", xmlns: "http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/encodedTypes" do
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
        end

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
        add_customer_data(xml, options)

        xml.target!
      end

      def add_credentials(xml)
        xml.tag! "ExactID", @options[:login]
        xml.tag! "Password", @options[:password]
      end

      def add_transaction_type(xml, action)
        xml.tag! "Transaction_Type", TRANSACTIONS[action]
      end

      def add_identification(xml, identification)
        authorization_num, transaction_tag, _ = identification.split(";")

        xml.tag! "Authorization_Num", authorization_num
        xml.tag! "Transaction_Tag", transaction_tag
      end

      def add_amount(xml, money, options)
        currency_code = options[:currency] || default_currency
        xml.tag! 'DollarAmount', localized_amount(money, currency_code)
        xml.tag! 'Currency', currency_code
      end

      def add_credit_card(xml, credit_card, options)
        if credit_card.respond_to?(:track_data) && credit_card.track_data.present?
          xml.tag! "Track1", credit_card.track_data
          xml.tag! "Ecommerce_Flag", "R"
        else
          xml.tag! "Card_Number", credit_card.number
          xml.tag! "Expiry_Date", expdate(credit_card)
          xml.tag! "CardHoldersName", credit_card.name
          xml.tag! "CardType", card_type(credit_card.brand)

          eci = (credit_card.respond_to?(:eci) ? credit_card.eci : nil) || options[:eci] || DEFAULT_ECI
          xml.tag! "Ecommerce_Flag", eci.to_s =~ /^[0-9]+$/ ? eci.to_s.rjust(2, '0') : eci

          add_credit_card_verification_strings(xml, credit_card, options)
        end
      end

      def add_credit_card_verification_strings(xml, credit_card, options)
        address = options[:billing_address] || options[:address]
        if address
          address_values = []
          [:address1, :zip, :city, :state, :country].each { |part| address_values << address[part].to_s }
          xml.tag! "VerificationStr1", address_values.join("|")
        end

        if credit_card.is_a?(NetworkTokenizationCreditCard)
          add_network_tokenization_credit_card(xml, credit_card)
        else
          if credit_card.verification_value?
            xml.tag! "CVD_Presence_Ind", "1"
            xml.tag! "VerificationStr2", credit_card.verification_value
          end

          add_card_authentication_data(xml, options)
        end
      end

      def add_network_tokenization_credit_card(xml, credit_card)
        case card_brand(credit_card).to_sym
        when :american_express
          cryptogram = Base64.decode64(credit_card.payment_cryptogram)
          xml.tag!("XID", Base64.encode64(cryptogram[20...40]))
          xml.tag!("CAVV", Base64.encode64(cryptogram[0...20]))
        else
          xml.tag!("XID", credit_card.transaction_id) if credit_card.transaction_id
          xml.tag!("CAVV", credit_card.payment_cryptogram)
        end
      end

      def add_card_authentication_data(xml, options)
        xml.tag! "CAVV", options[:cavv]
        xml.tag! "XID", options[:xid]
      end

      def add_credit_card_token(xml, store_authorization, options)
        params = store_authorization.split(";")
        credit_card = CreditCard.new(
          :brand      => params[1],
          :first_name => params[2],
          :last_name  => params[3],
          :month      => params[4],
          :year       => params[5])

        xml.tag! "TransarmorToken", params[0]
        xml.tag! "Expiry_Date", expdate(credit_card)
        xml.tag! "CardHoldersName", credit_card.name
        xml.tag! "CardType", card_type(credit_card.brand)
        add_card_authentication_data(xml, options)
      end

      def add_customer_data(xml, options)
        xml.tag! "Customer_Ref", options[:customer] if options[:customer]
        xml.tag! "Client_IP", options[:ip] if options[:ip]
        xml.tag! "Client_Email", options[:email] if options[:email]
      end

      def add_address(xml, options)
        if address = (options[:billing_address] || options[:address])
          xml.tag! "ZipCode", address[:zip]
        end
      end

      def add_invoice(xml, options)
        xml.tag! "Reference_No", options[:order_id]
        xml.tag! "Reference_3",  options[:description] if options[:description]
      end

      def add_tax_fields(xml, options)
        xml.tag! "Tax1Amount",  options[:tax1_amount] if options[:tax1_amount]
        xml.tag! "Tax1Number",  options[:tax1_number] if options[:tax1_number]
      end

      def add_level_3(xml, options)
        xml.tag!("Level3") { |x| x << options[:level_3] } if options[:level_3]
      end

      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def card_type(credit_card_brand)
        E4_BRANDS[credit_card_brand.to_sym] if credit_card_brand
      end

      def commit(action, request, credit_card = nil)
        url = (test? ? self.test_url : self.live_url)
        begin
          response = parse(ssl_post(url, build_request(action, request), POST_HEADERS))
        rescue ResponseError => e
          response = parse_error(e.response)
        end

        Response.new(successful?(response), message_from(response), response,
          :test => test?,
          :authorization => successful?(response) ? response_authorization(action, response, credit_card) : '',
          :avs_result => {:code => response[:avs]},
          :cvv_result => response[:cvv2],
          :error_code => standard_error_code(response)
        )
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
          ].join(";")
        else
          ""
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
            ].map { |value| value.to_s.gsub(/;/, "") }.join(";")
        else
          raise StandardError, "TransArmor support is not enabled on your #{display_name} account"
        end
      end

      def money_from_authorization(auth)
        _, _, amount = auth.split(/;/, 3)
        amount.to_i
      end

      def message_from(response)
        if(response[:faultcode] && response[:faultstring])
          response[:faultstring]
        elsif(response[:error_number] && response[:error_number] != "0")
          response[:error_description]
        else
          result = (response[:exact_message] || "")
          result << " - #{response[:bank_message]}" if response[:bank_message].present?
          result
        end
      end

      def parse_error(error)
        {
          :transaction_approved => "false",
          :error_number => error.code,
          :error_description => error.body,
          :ecommerce_error_code => error.body.gsub(/[^\d]/, '')
        }
      end

      def standard_error_code(response)
        STANDARD_ERROR_CODE_MAPPING[response[:bank_resp_code] || response[:ecommerce_error_code]]
      end

      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)

        if root = REXML::XPath.first(xml, "//TransactionResult")
          parse_elements(response, root)
        end

        response.delete_if{ |k,v| SENSITIVE_FIELDS.include?(k) }
      end

      def parse_elements(response, root)
        root.elements.to_a.each do |node|
          response[node.name.gsub(/EXact/, "Exact").underscore.to_sym] = (node.text || "").strip
        end
      end
    end
  end
end
