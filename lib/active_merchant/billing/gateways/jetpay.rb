module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class JetpayGateway < Gateway
      TEST_URL = 'https://test1.jetpay.com/jetpay'
      LIVE_URL = 'https://gateway17.jetpay.com/jetpay'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.jetpay.com/'
      
      # The name of the gateway
      self.display_name = 'JetPay'
      
      # all transactions are in cents
      self.money_format = :cents
      
      ACTION_CODE_MESSAGES = {
        "001" =>  "Refer to card issuer.",
        "002" =>  "Refer to card issuer, special condition.",
        "003" =>  "Pick up card.",
        "200" =>  "Deny - Pick up card.",
        "005" =>  "Do not honor.",
        "100" =>  "Deny.",
        "006" =>  "Error.",
        "181" =>  "Format error.",
        "007" =>  "Pickup card, special condition.",
        "104" =>  "Deny - New card issued.",
        "110" =>  "Invalid amount.",
        "014" =>  "Invalid account number (no such number).",
        "111" =>  "Invalid account.",
        "015" =>  "No such issuer.",
        "103" =>  "Deny - Invalid manual Entry 4DBC.",
        "182" =>  "Please wait.",
        "109" =>  "Invalid merchant.",
        "041" =>  "Pick up card (lost card).",
        "043" =>  "Pick up card (stolen card).",
        "051" =>  "Insufficient funds.",
        "052" =>  "No checking account.",
        "105" =>  "Deny - Account Cancelled.",
        "054" =>  "Expired Card.",
        "101" =>  "Expired Card.",
        "183" =>  "Invalid currency code.",
        "057" =>  "Transaction not permitted to cardholder.",
        "115" =>  "Service not permitted.",
        "062" =>  "Restricted card.",
        "189" =>  "Deny - Cancelled or Closed Merchant/SE.",
        "188" =>  "Deny - Expiration date required.",
        "125" =>  "Invalid effective date.",
        "122" =>  "Invalid card (CID) security code.",
        "400" =>  "Reversal accepted.",
        "992" =>  "DECLINE/TIMEOUT.",
        "107" =>  "Please Call Issuer.",
        "025" =>  "Transaction Not Found.",
        "981" =>  "AVS Error.",
        "913" =>  "Invalid Card Type.",
        "996" =>  "Terminal ID Not Found."
      }
      
      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end  
      
      def purchase(money, credit_card, options = {})
        commit(money, build_sale_request(money, credit_card, options))
      end
      
      def authorize(money, credit_card, options = {})
        commit(money, build_authonly_request(money, credit_card, options))
      end
      
      def capture(money, reference, options = {})
        commit(money, build_capture_request('CAPT', reference.split(";").first))
      end
      
      def void(reference, options = {})
        transaction_id, approval, amount = reference.split(";")
        commit(amount.to_i, build_void_request(amount.to_i, transaction_id, approval))
      end

      def credit(money, transaction_id_or_card, options = {})
        if transaction_id_or_card.is_a?(String)
          warn CREDIT_DEPRECATION_MESSAGE
          refund(money, transaction_id_or_card, options)
        else
          commit(money, build_credit_request('CREDIT', money, nil, transaction_id_or_card))
        end
      end

      def refund(money, reference, options = {})
        transaction_id = reference.split(";").first
        credit_card = options[:credit_card]
        commit(money, build_credit_request('CREDIT', money, transaction_id, credit_card))
      end

      
      private
      
      def build_xml_request(transaction_type, transaction_id = nil, &block)
        xml = Builder::XmlMarkup.new
        xml.tag! 'JetPay' do
          # The basic values needed for any request
          xml.tag! 'TerminalID', @options[:login]
          xml.tag! 'TransactionType', transaction_type
          xml.tag! 'TransactionID', transaction_id.nil? ? generate_unique_id.slice(0, 18) : transaction_id
          
          if block_given?
            yield xml
          else 
            xml.target!
          end
        end
      end
      
      def build_sale_request(money, credit_card, options)
        build_xml_request('SALE') do |xml|
          add_credit_card(xml, credit_card)
          add_addresses(xml, options)
          add_customer_data(xml, options)
          add_invoice_data(xml, options)
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
          xml.tag! 'TotalAmount', amount(money)
          
          xml.target!
        end
      end
      
      def build_capture_request(transaction_type, transaction_id)
        build_xml_request(transaction_type, transaction_id)
      end
      
      def build_void_request(money, transaction_id, approval)
        build_xml_request('VOID', transaction_id) do |xml|
          xml.tag! 'Approval', approval
          xml.tag! 'TotalAmount', amount(money)
          
          xml.target!
        end        
      end

      # `transaction_id` may be nil for unlinked credit transactions.
      def build_credit_request(transaction_type, money, transaction_id, card)
        build_xml_request(transaction_type, transaction_id) do |xml|
          add_credit_card(xml, card) if card
          xml.tag! 'TotalAmount', amount(money)
          
          xml.target!
        end
      end
      
      def commit(money, request)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, request))
        
        success = success?(response)
        Response.new(success, 
          success ? 'APPROVED' : message_from(response), 
          response, 
          :test => test?, 
          :authorization => authorization_from(response, money),
          :avs_result => { :code => response[:avs] },
          :cvv_result => response[:cvv2]
        )
      end
      
      def parse(body)
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
      
      def authorization_from(response, money)
        original_amount = amount(money) if money
        [ response[:transaction_id], response[:approval], original_amount ].join(";")
      end
      
      def add_credit_card(xml, credit_card)
        xml.tag! 'CardNum', credit_card.number
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
      
      def lookup_country_code(code)
        country = Country.find(code) rescue nil        
        country && country.code(:alpha3)
      end
    end
  end
end

