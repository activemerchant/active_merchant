require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # To learn more about the Moneris gateway, please contact 
    # eselectplus@moneris.com for a copy of their integration guide. For 
    # information on remote testing, please see "Test Environment Penny Value 
    # Response Table", and "Test Environment eFraud (AVS and CVD) Penny 
    # Response Values", available at Moneris' {eSelect Plus Documentation 
    # Centre}[https://www3.moneris.com/connect/en/documents/index.html].
    class MonerisGateway < Gateway
      self.test_url = 'https://esqa.moneris.com/gateway2/servlet/MpgRequest'
      self.live_url = 'https://www3.moneris.com/gateway2/servlet/MpgRequest'
      
      self.supported_countries = ['CA']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover]
      self.homepage_url = 'http://www.moneris.com/'
      self.display_name = 'Moneris'
  
      # login is your Store ID
      # password is your API Token
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = { :crypt_type => 7 }.update(options)
        super      
      end      
    
      # Referred to as "PreAuth" in the Moneris integration guide, this action 
      # verifies and locks funds on a customer's card, which then must be 
      # captured at a later date.
      # 
      # Pass in +order_id+ and optionally a +customer+ parameter.
      def authorize(money, creditcard_or_datakey, options = {})
        requires!(options, :order_id)
        post = {}
        add_payment_source(post, creditcard_or_datakey)
        post[:amount]     = amount(money)
        post[:order_id]   = options[:order_id]
        post[:cust_id]    = options[:customer]
        post[:crypt_type] = options[:crypt_type] || @options[:crypt_type]
        action = (post[:data_key].blank?) ? 'preauth' : 'res_preauth_cc'
        commit(action, post)
      end
      
      # This action verifies funding on a customer's card and readies them for
      # deposit in a merchant's account.
      # 
      # Pass in <tt>order_id</tt> and optionally a <tt>customer</tt> parameter
      def purchase(money, creditcard_or_datakey, options = {})
        requires!(options, :order_id)
        post = {}
        add_payment_source(post, creditcard_or_datakey)
        post[:amount]     = amount(money)
        post[:order_id]   = options[:order_id]
        post[:cust_id]    = options[:customer]
        post[:crypt_type] = options[:crypt_type] || @options[:crypt_type]
        action = (post[:data_key].blank?) ? 'purchase' : 'res_purchase_cc'
        commit(action, post)
      end

      # This method retrieves locked funds from a customer's account (from a 
      # PreAuth) and prepares them for deposit in a merchant's account.
      # 
      # Note: Moneris requires both the order_id and the transaction number of
      # the original authorization.  To maintain the same interface as the other
      # gateways the two numbers are concatenated together with a ; separator as
      # the authorization number returned by authorization
      def capture(money, authorization, options = {})
        commit 'completion', crediting_params(authorization, :comp_amount => amount(money))
      end

      # Voiding requires the original transaction ID and order ID of some open 
      # transaction. Closed transactions must be refunded. Note that the only 
      # methods which may be voided are +capture+ and +purchase+.
      # 
      # Concatenate your transaction number and order_id by using a semicolon 
      # (';'). This is to keep the Moneris interface consistent with other 
      # gateways. (See +capture+ for details.)
      def void(authorization, options = {})
        commit 'purchasecorrection', crediting_params(authorization)
      end
      
      # Performs a refund. This method requires that the original transaction 
      # number and order number be included. Concatenate your transaction 
      # number and order_id by using a semicolon (';'). This is to keep the 
      # Moneris interface consistent with other gateways. (See +capture+ for 
      # details.)
      def credit(money, authorization, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end
   
      def refund(money, authorization, options = {})
        commit 'refund', crediting_params(authorization, :amount => amount(money))
      end

      def store(credit_card, options = {})
        post = {}
        post[:pan] = credit_card.number
        post[:expdate] = expdate(credit_card)
        post[:crypt_type] = options[:crypt_type] || @options[:crypt_type]
        commit('res_add_cc', post)
      end

      def unstore(data_key)
        post = {}
        post[:data_key] = data_key
        commit('res_delete', post)
      end

      def update(data_key, credit_card, options = {})
        post = {}
        post[:pan] = credit_card.number
        post[:expdate] = expdate(credit_card)
        post[:data_key] = data_key
        post[:crypt_type] = options[:crypt_type] || @options[:crypt_type]
        commit('res_update_cc', post)
      end

      def test?
        @options[:test] || super
      end

    private # :nodoc: all
    
      def expdate(creditcard)
        sprintf("%.4i", creditcard.year)[-2..-1] + sprintf("%.2i", creditcard.month)
      end

      def add_payment_source(post, source)
        if source.is_a?(String)
          post[:data_key]   = source
        else
          post[:pan]        = source.number
          post[:expdate]    = expdate(source)
        end
      end
      
      # Common params used amongst the +credit+, +void+ and +capture+ methods
      def crediting_params(authorization, options = {})
        {
          :txn_number => split_authorization(authorization).first, 
          :order_id   => split_authorization(authorization).last, 
          :crypt_type => options[:crypt_type] || @options[:crypt_type]
        }.merge(options)
      end
      
      # Splits an +authorization+ param and retrives the order id and 
      # transaction number in that order.
      def split_authorization(authorization)
        if authorization.nil? || authorization.empty? || authorization !~ /;/
          raise ArgumentError, 'You must include a valid authorization code (e.g. "1234;567")' 
        else
          authorization.split(';')
        end
      end
  
      def commit(action, parameters = {})
        response = parse(ssl_post(test? ? self.test_url : self.live_url, post_data(action, parameters)))

        Response.new(successful?(response), message_from(response[:message]), response,
          :test          => test?,
          :authorization => authorization_from(response)
        )
      end
      
      # Generates a Moneris authorization string of the form 'trans_id;receipt_id'.
      def authorization_from(response = {})
        if response[:trans_id] && response[:receipt_id]
          "#{response[:trans_id]};#{response[:receipt_id]}"
        end
      end
      
      # Tests for a successful response from Moneris' servers
      def successful?(response)
        response[:response_code] && 
        response[:complete] && 
        (0..49).include?(response[:response_code].to_i)
      end
                                               
      def parse(xml)
        response = { :message => "Global Error Receipt", :complete => false }
        hashify_xml!(xml, response)
        response
      end
      
      def hashify_xml!(xml, response)
        xml = REXML::Document.new(xml)
        return if xml.root.nil?
        xml.elements.each('//receipt/*') do |node|
          response[node.name.underscore.to_sym] = normalize(node.text)
        end
      end

      def post_data(action, parameters = {})
        xml   = REXML::Document.new
        root  = xml.add_element("request")
        root.add_element("store_id").text  = options[:login]
        root.add_element("api_token").text = options[:password]
        transaction = root.add_element(action)

        # Must add the elements in the correct order
        actions[action].each do |key|
          transaction.add_element(key.to_s).text = parameters[key] unless parameters[key].blank?
        end
        
        xml.to_s
      end
    
      def message_from(message)
        return 'Unspecified error' if message.blank?
        message.gsub(/[^\w]/, ' ').split.join(" ").capitalize
      end

      # Make a Ruby type out of the response string
      def normalize(field)
        case field
          when "true"     then true
          when "false"    then false
          when '', "null" then nil
          else field
        end        
      end
      
      def actions
        {
          "purchase"           => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
          "preauth"            => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
          "command"            => [:order_id],
          "refund"             => [:order_id, :amount, :txn_number, :crypt_type],
          "indrefund"          => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
          "completion"         => [:order_id, :comp_amount, :txn_number, :crypt_type],
          "purchasecorrection" => [:order_id, :txn_number, :crypt_type],
          "cavvpurcha"         => [:order_id, :cust_id, :amount, :pan, :expdate, :cav],
          "cavvpreaut"         => [:order_id, :cust_id, :amount, :pan, :expdate, :cavv],
          "transact"           => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
          "Batchcloseall"      => [],
          "opentotals"         => [:ecr_number],
          "batchclose"         => [:ecr_number],
          "res_add_cc"         => [:pan, :expdate, :crypt_type],
          "res_delete"         => [:data_key],
          "res_update_cc"      => [:data_key, :pan, :expdate, :crypt_type],
          "res_purchase_cc"    => [:data_key, :order_id, :cust_id, :amount, :crypt_type],
          "res_preauth_cc"     => [:data_key, :order_id, :cust_id, :amount, :crypt_type]
        }
      end
    end
  end
end
