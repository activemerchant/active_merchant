module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayleaseGateway < Gateway
      LIVE_URL = 'https://www.paylease.com/gapi/request.php'
      TEST_URL = LIVE_URL
      
      CC_PAYMENT = 'CCPayment'
      CC_TRANSACTION = 'CCTransaction'
      AUTHORIZE = 'AUTH'
      CAPTURE = 'CAPTURE'
      
      SUCCESS_CODES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 182, 183, 189]
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.paylease.com/'
      self.display_name = 'PayLease - Credit Card'
      
      
      def initialize(options = {})
        requires!(options, :login, :password, :gateway_id, :payee_id)
        @options = options
        super
      end  
      
      
      def authorize(money, creditcard, options = {})
        requires!(options, :payer_reference_id)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'PayLeaseGatewayRequest' do
          add_credentials(xml, options)
          add_mode(xml, options)
          add_cc_authorize_transactions(xml, money, creditcard, options)
        end 
        commit(xml.target!)
      end
      
      
      def capture(money, authorization, options = {})
        requires!(options, :payer_reference_id)
        requires!(options, :transaction_id)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'PayLeaseGatewayRequest' do
          add_credentials(xml, options)
          add_mode(xml, options)
          add_cc_capture_transactions(xml, money, authorization, options)
        end 
        commit(xml.target!)
      end
      
      
      def purchase(money, creditcard, options = {})
        requires!(options, :payer_reference_id)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag! 'PayLeaseGatewayRequest' do
          add_credentials(xml, options)
          add_mode(xml, options)
          add_cc_purchase_transactions(xml, money, creditcard, options)
        end 
        commit(xml.target!)
      end                       

    
      private

      
      def add_credentials(xml, options)
        xml.tag! 'Credentials' do
          xml.tag! 'GatewayId', @options[:gateway_id]
          xml.tag! 'Username', @options[:login]
          xml.tag! 'Password', @options[:password]
        end
      end
      
      
      def add_mode(xml, options)
        xml.tag! 'Mode', test? ? 'Test' : 'Production'
      end
      
      
      def add_cc_authorize_transactions(xml, money, creditcard, options)
        xml.tag! 'Transactions' do
          xml.tag! 'Transaction' do
            xml.tag! 'TransactionAction', CC_PAYMENT
            xml.tag! 'CreditCardAction', AUTHORIZE
            xml.tag! 'PaymentReferenceId', options[:payment_reference_id] || SecureRandom.hex(10)
            xml.tag! 'PaymentTraceId', options[:payment_trace_id] || SecureRandom.hex(10)
            xml.tag! 'PayerReferenceId', options[:payer_reference_id]
            xml.tag! 'PayeeId', @options[:payee_id]
            xml.tag! 'PayerFirstName', creditcard.first_name
            xml.tag! 'PayerLastName', creditcard.last_name
            
            xml.tag! 'CreditCardType', credit_card_type(creditcard)
            xml.tag! 'CreditCardNumber', creditcard.number
            xml.tag! 'CreditCardExpMonth', format(creditcard.month, :two_digits)
            xml.tag! 'CreditCardExpYear', format(creditcard.year, :two_digits)
            xml.tag! 'CreditCardCvv2', creditcard.verification_value if creditcard.verification_value?
            
            xml.tag! 'BillingFirstName', creditcard.first_name
            xml.tag! 'BillingLastName', creditcard.last_name
            if address = options[:billing_address] || options[:address]
              xml.tag! 'BillingStreetAddress', address[:address1].to_s
              xml.tag! 'BillingCity', address[:city].to_s
              xml.tag! 'BillingState', address[:state].to_s
              xml.tag! 'BillingCountry', 'US' # only accepted value
              xml.tag! 'BillingZip', address[:zip].to_s
            end
            
            xml.tag! 'TotalAmount', amount(money)
            xml.tag! 'FeeAmount', '0.00'
            xml.tag! 'SaveAccount', 'No'
          end
        end
      end
      
      
      def add_cc_capture_transactions(xml, money, authorization, options)
        xml.tag! 'Transactions' do
          xml.tag! 'Transaction' do
            xml.tag! 'TransactionAction', CC_TRANSACTION
            xml.tag! 'CreditCardAction', CAPTURE
            xml.tag! 'TransactionId', authorization
            xml.tag! 'GatewayPayerId', options[:transaction_id]
          end
        end
      end
      

      def add_cc_purchase_transactions(xml, money, creditcard, options)
        xml.tag! 'Transactions' do
          xml.tag! 'Transaction' do
            xml.tag! 'TransactionAction', CC_PAYMENT
            xml.tag! 'PaymentReferenceId', options[:payment_reference_id] || SecureRandom.hex(10)
            xml.tag! 'PaymentTraceId', options[:payment_trace_id] || SecureRandom.hex(10)
            xml.tag! 'PayerReferenceId', options[:payer_reference_id]
            xml.tag! 'PayeeId', @options[:payee_id]
            xml.tag! 'PayerFirstName', creditcard.first_name
            xml.tag! 'PayerLastName', creditcard.last_name
            
            xml.tag! 'CreditCardType', credit_card_type(creditcard)
            xml.tag! 'CreditCardNumber', creditcard.number
            xml.tag! 'CreditCardExpMonth', format(creditcard.month, :two_digits)
            xml.tag! 'CreditCardExpYear', format(creditcard.year, :two_digits)
            xml.tag! 'CreditCardCvv2', creditcard.verification_value if creditcard.verification_value?
            
            xml.tag! 'BillingFirstName', creditcard.first_name
            xml.tag! 'BillingLastName', creditcard.last_name
            if address = options[:billing_address] || options[:address]
              xml.tag! 'BillingStreetAddress', address[:address1].to_s
              xml.tag! 'BillingCity', address[:city].to_s
              xml.tag! 'BillingState', address[:state].to_s
              xml.tag! 'BillingCountry', 'US' # only accepted value
              xml.tag! 'BillingZip', address[:zip].to_s
            end
            
            xml.tag! 'TotalAmount', amount(money)
            xml.tag! 'FeeAmount', '0.00'
            xml.tag! 'SaveAccount', 'No'
          end
        end
      end
      
            
      def credit_card_type(creditcard)
        case creditcard.type
        when "visa"
          'Visa'
        when "master"
          'MasterCard'
        when "discover"
          'Discover'
        when "american_express"
          'Amex'
        end
      end


      def commit(xml)
        url = test? ? TEST_URL : LIVE_URL

        data = ssl_post url, post_data(xml)
        response = parse(data)
        # response[:original_request] = post_data(xml)
        message = message_from(response)
        
        Response.new(success?(response), message, response, 
          :test => response[:test], 
          :authorization => response[:authorization],
        )
      end
      
      
      def post_data(xml)
        post = {}
        post['XML'] = xml
        post.to_query
      end
      
      
      def parse(data)
        response = {}
        response[:original_data] = data
        
        xml = REXML::Document.new(data)
        raise "Gateway response does not appear to be XML" unless xml.root
        response[:test] = xml.root.elements["Mode"].text == "Test"
        
        parsed = REXML::XPath.first(xml, "//Transaction") || parsed = REXML::XPath.first(xml, "//Error")
        if parsed
          response[:authorization] = parsed.elements['TransactionId'].text if parsed.elements['TransactionId']
          response[:transaction_id] = parsed.elements['ApprovalCode'].text if parsed.elements['ApprovalCode']
          response[:status] = parsed.elements['Status'].text
          response[:code] = parsed.elements['Code'].text.to_i
          response[:message] = parsed.elements['Message'].text
        else
          raise "Unknown response from paylease: #{data}"
        end
                
        response
      end
      

      def message_from(response)
        message = response[:status]
        if response.has_key?(:code) && !SUCCESS_CODES.include?(response[:code])
          message += " - #{response[:message]}"
        end
        message
      end
      
      
      def success?(response)
        response.has_key?(:code) && SUCCESS_CODES.include?(response[:code])
      end
      
    end
  end
end

