module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class JetpayGateway < Gateway
      class_attribute :live_us_url, :live_ca_url

      self.test_url = 'https://test1.jetpay.com/jetpay'
      self.live_us_url = 'https://gateway17.jetpay.com/jetpay'
      self.live_ca_url = 'https://gateway17.jetpay.com/canada-bb'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US', 'CA']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.jetpay.com/'

      # The name of the gateway
      self.display_name = 'JetPay'

      # all transactions are in cents
      self.money_format = :cents

      ACTION_CODE_MESSAGES = {
        "000" =>  "Approved.",
        "001" =>  "Refer to card issuer.",
        "002" =>  "Refer to card issuer, special condition.",
        "003" =>  "Invalid merchant or service provider.",
        "004" =>  "Pick up card.",
        "005" =>  "Do not honor.",
        "006" =>  "Error.",
        "007" =>  "Pick up card, special condition.",
        "008" =>  "Honor with ID (Show ID).",
        "010" =>  "Partial approval.",
        "011" =>  "VIP approval.",
        "012" =>  "Invalid transaction.",
        "013" =>  "Invalid amount or exceeds maximum for card program.",
        "014" =>  "Invalid account number (no such number).",
        "015" =>  "No such issuer.",
        "019" =>  "Re-enter Transaction.",
        "021" =>  "No action taken (unable to back out prior transaction).",
        "025" =>  "Transaction Not Found.",
        "027" =>  "File update field edit error.",
        "028" =>  "File is temporarily unavailable.",
        "030" =>  "Format error.",
        "039" =>  "No credit account.",
        "041" =>  "Pick up card (lost card).",
        "043" =>  "Pick up card (stolen card).",
        "051" =>  "Insufficient funds.",
        "052" =>  "No checking account.",
        "053" =>  "Mp savomgs accpimt.",
        "054" =>  "Expired Card.",
        "055" =>  "Incorrect PIN.",
        "057" =>  "Transaction not permitted to cardholder.",
        "058" =>  "Transaction not allowed at terminal.",
        "061" =>  "Exceeds withdrawal limit.",
        "062" =>  "Restricted card (eg, Country Exclusion).",
        "063" =>  "Security violation.",
        "065" =>  "Activity count limit exceeded.",
        "068" =>  "Response late.",
        "070" =>  "Contact card issuer.",
        "071" =>  "PIN not changed.",
        "075" =>  "Allowable number of PIN-entry tries exceeded.",
        "076" =>  "Unable to locate previous message (no matching retrieval reference number).",
        "077" =>  "Repeat or reversal data are inconsistent with original message.",
        "078" =>  "Blocked (first use), or non-existent account.",
        "079" =>  "Key exchange validation failed.",
        "080" =>  "Credit issuer unavailable or invalid date.",
        "081" =>  "PIN cryptographic error found.",
        "082" =>  "Negative online CVV results.",
        "084" =>  "Invalid auth life cycle.",
        "085" =>  "No reason to decline - CVV or AVS approved.",
        "086" =>  "Cannot verify PIN.",
        "087" =>  "Cashback not allowed.",
        "089" =>  "Issuer Down.",
        "091" =>  "Issuer Down.",
        "092" =>  "Unable to route transaction.",
        "093" =>  "Transaction cannot be completed - violation of law.",
        "094" =>  "Duplicate transmission.",
        "096" =>  "System error.",
        "100" =>  "Deny.",
        "101" =>  "Expired Card.",
        "103" =>  "Deny - Invalid manual Entry 4DBC.",
        "104" =>  "Deny - New card issued.",
        "105" =>  "Deny - Account Cancelled.",
        "106" =>  "Exceeded PIN Attempts.",
        "107" =>  "Please Call Issuer.",
        "109" =>  "Invalid merchant.",
        "110" =>  "Invalid amount.",
        "111" =>  "Invalid account.",
        "115" =>  "Service not permitted.",
        "122" =>  "Invalid card (CID) security code.",
        "125" =>  "Invalid effective date.",
        "181" =>  "Format error.",
        "182" =>  "Please wait.",
        "183" =>  "Invalid currency code.",
        "187" =>  "Deny - new card issued.",
        "188" =>  "Deny - Expiration date required.",
        "189" =>  "Deny - Cancelled or Closed Merchant/SE.",
        "200" =>  "Deny - Pick up card.",
        "400" =>  "Reversal accepted.",
        "601" =>  "Reject - EMV Chip Declined Transaction.",
        "602" =>  "Reject - Suspected Fraud.",
        "603" =>  "Reject - Communications Error.",
        "604" =>  "Reject - Insufficient Approval.",
        "750" =>  "Velocity Check Fail.",
        "899" =>  "Misc Decline.",
        "900" =>  "Invalid Message Type.",
        "901" =>  "Invalid Merchant ID.",
        "903" =>  "Debit not supported.",
        "904" =>  "Private label not supported.",
        "905" =>  "Invalid card type.",
        "906" =>  "Unit not active.",
        "908" =>  "Manual card entry invalid.",
        "909" =>  "Invalid track information.",
        "911" =>  "Master merchant not found.",
        "912" =>  "Invalid card format.",
        "913" =>  "Invalid card type.",
        "914" =>  "Invalid card length.",
        "917" =>  "Expired card.",
        "919" =>  "Invalid entry type.",
        "920" =>  "Invalid amount.",
        "921" =>  "Invalid messge format.",
        "923" =>  "Invalid ABA.",
        "924" =>  "Invalid DDA.",
        "925" =>  "Invalid TID.",
        "926" =>  "Invalid Password.",
        "930" =>  "Invalid zipcode.",
        "931" =>  "Invalid Address.",
        "932" =>  "Invalid ZIP and Address.",
        "933" =>  "Invalid CVV2.",
        "934" =>  "Program Not Allowed.",
        "940" =>  "Record Not Found.",
        "941" =>  "Merchant ID error.",
        "942" =>  "Refund Not Allowed.",
        "943" =>  "Refund denied.",
        "955" =>  "Invalid PIN block.",
        "956" =>  "Invalid KSN.",
        "958" =>  "Bad Status.",
        "959" =>  "Seek Record limit exceeded.",
        "962" =>  "Invalid PIN key (Unknown KSN).",
        "981" =>  "Invalid AVS.",
        "987" =>  "Issuer Unavailable.",
        "988" =>  "System error SD.",
        "989" =>  "Database Error.",
        "992" =>  "Transaction Timeout.",
        "996" =>  "Bad Terminal ID.",
        "997" =>  "Message rejected by association.",
        "999" =>  "Communication failure",
        nil   =>  "No response returned (missing credentials?)."
      }

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def purchase(money, credit_card, options = {})
        commit(money, build_sale_request(money, credit_card, options))
      end

      def authorize(money, credit_card, options = {})
        commit(money, build_authonly_request(money, credit_card, options))
      end

      def capture(money, reference, options = {})
        split_authorization = reference.split(";")
        transaction_id = split_authorization[0]
        token = split_authorization[3]
        commit(money, build_capture_request(transaction_id, money, options), token)
      end

      def void(reference, options = {})
        transaction_id, approval, amount, token = reference.split(";")
        commit(amount.to_i, build_void_request(amount.to_i, transaction_id, approval, token, options), token)
      end

      def credit(money, transaction_id_or_card, options = {})
        if transaction_id_or_card.is_a?(String)
          ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
          refund(money, transaction_id_or_card, options)
        else
          commit(money, build_credit_request('CREDIT', money, nil, transaction_id_or_card, nil, options))
        end
      end

      def refund(money, reference, options = {})
        split_authorization = reference.split(";")
        transaction_id = split_authorization[0]
        token = split_authorization[3]
        credit_card = options[:credit_card]
        commit(money, build_credit_request('CREDIT', money, transaction_id, credit_card, token, options))
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((>)\d+(</CardNum>)), '\1[FILTERED]\2').
          gsub(%r((<CVV2>)\d+(</CVV2>)), '\1[FILTERED]\2')
      end

      private

      def build_xml_request(transaction_type, options = {}, transaction_id = nil, &block)
        xml = Builder::XmlMarkup.new
        xml.tag! 'JetPay' do
          # The basic values needed for any request
          xml.tag! 'TerminalID', @options[:login]
          xml.tag! 'TransactionType', transaction_type
          xml.tag! 'TransactionID', transaction_id.nil? ? generate_unique_id.slice(0, 18) : transaction_id
          if options && options[:origin]
            xml.tag! 'Origin', options[:origin]
          end

          if block_given?
            yield xml
          else
            xml.target!
          end
        end
      end

      def build_sale_request(money, credit_card, options)
        build_xml_request('SALE', options) do |xml|
          add_credit_card(xml, credit_card)
          add_addresses(xml, options)
          add_customer_data(xml, options)
          add_invoice_data(xml, options)
          add_user_defined_fields(xml, options)
          xml.tag! 'TotalAmount', amount(money)

          xml.target!
        end
      end

      def build_authonly_request(money, credit_card, options)
        build_xml_request('AUTHONLY') do |xml|
          add_credit_card(xml, credit_card)
          add_addresses(xml, options)
          add_customer_data(xml, options)
          add_invoice_data(xml, options)
          add_user_defined_fields(xml, options)
          xml.tag! 'TotalAmount', amount(money)

          xml.target!
        end
      end

      def build_capture_request(transaction_id, money, options)
        build_xml_request('CAPT', options, transaction_id) do |xml|
          xml.tag! 'TotalAmount', amount(money)
          add_user_defined_fields(xml, options)
        end
      end

      def build_void_request(money, transaction_id, approval, token, options)
        build_xml_request('VOID', options, transaction_id) do |xml|
          xml.tag! 'Approval', approval
          xml.tag! 'TotalAmount', amount(money)
          xml.tag! 'Token', token if token
          xml.target!
        end
      end

      # `transaction_id` may be nil for unlinked credit transactions.
      def build_credit_request(transaction_type, money, transaction_id, card, token, options)
        build_xml_request(transaction_type, options, transaction_id) do |xml|
          add_credit_card(xml, card) if card
          add_invoice_data(xml, options)
          add_addresses(xml, options)
          add_customer_data(xml, options)
          add_user_defined_fields(xml, options)
          xml.tag! 'TotalAmount', amount(money)
          xml.tag! 'Token', token if token

          xml.target!
        end
      end

      def commit(money, request, token = nil)
        response = parse(ssl_post(url, request))

        success = success?(response)
        Response.new(success,
          success ? 'APPROVED' : message_from(response),
          response,
          :test => test?,
          :authorization => authorization_from(response, money, token),
          :avs_result => { :code => response[:avs] },
          :cvv_result => response[:cvv2]
        )
      end

      def url
        live_url = @options[:region] == 'CA' ? live_ca_url : live_us_url
        test? ? test_url : live_url
      end

      def parse(body)
        return {} if body.blank?

        xml = REXML::Document.new(body)

        response = {}
        xml.root.elements.to_a.each do |node|
          parse_element(response, node)
        end
        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def format_exp(value)
        format(value, :two_digits)
      end

      def success?(response)
        response[:action_code] == "000"
      end

      def message_from(response)
        ACTION_CODE_MESSAGES[response[:action_code]]
      end

      def authorization_from(response, money, previous_token)
        original_amount = amount(money) if money
        [ response[:transaction_id], response[:approval], original_amount, (response[:token] || previous_token)].join(";")
      end

      def add_credit_card(xml, credit_card)
        xml.tag! 'CardNum', credit_card.number, "Tokenize" => true
        xml.tag! 'CardExpMonth', format_exp(credit_card.month)
        xml.tag! 'CardExpYear', format_exp(credit_card.year)

        if credit_card.first_name || credit_card.last_name
          xml.tag! 'CardName', [credit_card.first_name,credit_card.last_name].compact.join(' ')
        end

        unless credit_card.verification_value.nil? || (credit_card.verification_value.length == 0)
          xml.tag! 'CVV2', credit_card.verification_value
        end
      end

      def add_addresses(xml, options)
        if billing_address = options[:billing_address] || options[:address]
          xml.tag! 'BillingAddress', [billing_address[:address1], billing_address[:address2]].compact.join(" ")
          xml.tag! 'BillingCity', billing_address[:city]
          xml.tag! 'BillingStateProv', billing_address[:state]
          xml.tag! 'BillingPostalCode', billing_address[:zip]
          xml.tag! 'BillingCountry', lookup_country_code(billing_address[:country])
          xml.tag! 'BillingPhone', billing_address[:phone]
        end

        if shipping_address = options[:shipping_address]
          xml.tag! 'ShippingInfo' do
            xml.tag! 'ShippingName', shipping_address[:name]

            xml.tag! 'ShippingAddr' do
              xml.tag! 'Address', [shipping_address[:address1], shipping_address[:address2]].compact.join(" ")
              xml.tag! 'City', shipping_address[:city]
              xml.tag! 'StateProv', shipping_address[:state]
              xml.tag! 'PostalCode', shipping_address[:zip]
              xml.tag! 'Country', lookup_country_code(shipping_address[:country])
            end
          end
        end
      end

      def add_customer_data(xml, options)
        xml.tag! 'Email', options[:email] if options[:email]
        xml.tag! 'UserIPAddress', options[:ip] if options[:ip]
      end

      def add_invoice_data(xml, options)
        xml.tag! 'OrderNumber', options[:order_id] if options[:order_id]
        xml.tag! 'TaxAmount', amount(options[:tax]) if options[:tax]
      end

      def add_user_defined_fields(xml, options)
        xml.tag! 'UDField1', options[:ud_field_1] if options[:ud_field_1]
        xml.tag! 'UDField2', options[:ud_field_2] if options[:ud_field_2]
        xml.tag! 'UDField3', options[:ud_field_3] if options[:ud_field_3]
      end

      def lookup_country_code(code)
        country = Country.find(code) rescue nil
        country && country.code(:alpha3)
      end
    end
  end
end
