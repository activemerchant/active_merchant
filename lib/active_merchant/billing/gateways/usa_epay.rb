module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
        
    class UsaEpayGateway < Gateway
    	GATEWAY_URL = 'https://www.usaepay.com/gate.php'
      POST_HEADERS = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      
      attr_reader :url 
      attr_reader :response
      attr_reader :options
      
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.supported_countries = ['US']
      self.homepage_url = 'http://www.usa_epay.com/'
      self.display_name = 'USA ePay'

      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('authonly', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('sale', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post = {:refNum => authorization}
        commit('capture', money, post)
      end
       
      private                       
    
      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end
      
      def add_customer_data(post, options)
        address = options[:billing_address] || options[:address] || {}
        post[:street] = address[:address1]
        post[:zip] = address[:zip]

        if options.has_key? :email
          post[:custemail] = options[:email]
          post[:custreceipt] = 'No'
        end
        
        if options.has_key? :customer
          post[:custid] = options[:customer]
        end
        
        if options.has_key? :ip
          post[:ip] = options[:ip]
        end        
      end

      def add_address(post, creditcard, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address] || billing_address
        
        add_address_for_type(:billing, post, creditcard, billing_address) unless billing_address.nil?
        add_address_for_type(:shipping, post, creditcard, shipping_address) unless shipping_address.nil?
      end

      def add_address_for_type(type, post, creditcard, address)
        prefix = address_key_prefix(type)

        post[address_key(prefix, 'fname')] = creditcard.first_name
        post[address_key(prefix, 'lname')] = creditcard.last_name
        post[address_key(prefix, 'company')] = address[:company] unless address[:company].blank?
        post[address_key(prefix, 'street')] = address[:address1] unless address[:address1].blank?
        post[address_key(prefix, 'street2')] = address[:address2] unless address[:address2].blank?
        post[address_key(prefix, 'city')] = address[:city] unless address[:city].blank?
        post[address_key(prefix, 'state')] = address[:state] unless address[:state].blank?
        post[address_key(prefix, 'zip')] = address[:zip] unless address[:zip].blank?
        post[address_key(prefix, 'country')] = address[:country] unless address[:country].blank?
        post[address_key(prefix, 'phone')] = address[:phone] unless address[:phone].blank?
      end
      
      def address_key_prefix(type)  
        case type
        when :shipping then 'ship'
        when :billing then 'bill'
        end
      end

      def address_key(prefix, key)
        "#{prefix}#{key}".to_sym
      end
      
      def add_invoice(post, options)
        post[:invoice] = options[:order_id]
      end
      
      def add_creditcard(post, creditcard)      
        post[:card]  = creditcard.number
        post[:cvv2] = creditcard.verification_value if creditcard.verification_value?
        post[:expir]  = expdate(creditcard)
        post[:name] = creditcard.name
      end
      
      def parse(body)
        fields = {}
        for line in body.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key] = CGI.unescape(value)
        end

        {
          :status => fields['UMstatus'],
          :auth_code => fields['UMauthCode'],
          :ref_num => fields['UMrefNum'],
          :batch => fields['UMbatch'],
          :avs_result => fields['UMavsResult'],
          :avs_result_code => fields['UMavsResultCode'],
          :cvv2_result => fields['UMcvv2Result'],
          :cvv2_result_code => fields['UMcvv2ResultCode'],
          :vpas_result_code => fields['UMvpasResultCode'],
          :result => fields['UMresult'],
          :error => fields['UMerror'],
          :error_code => fields['UMerrorcode'],
          :acs_url => fields['UMacsurl'],
          :payload => fields['UMpayload']
        }.delete_if{|k, v| v.nil?}         
      end     

      
      def commit(action, money, parameters)
        parameters[:software] = 'Active Merchant'
        parameters[:amount]       = amount(money)
        parameters[:testmode] = test? ? 1 : 0
        
        if result = test_result_from_cc_number(parameters[:card])
          return result
        end
                   
        data = ssl_post(GATEWAY_URL, post_data(action, parameters), POST_HEADERS)
        
        @response = parse(data)
        success = @response[:status] == 'Approved'
        message = message_from(@response)

        Response.new(success, message, @response, 
            :test => test?,
            :authorization => @response[:ref_num]
        )        
      end

      def message_from(response)
        if response[:status] == "Approved"
          return 'Success'
        else
          return 'Unspecified error' if response[:error].blank?
          return response[:error]
        end
      end
      
      def post_data(action, parameters = {})
        post = {}
  
        post[:command]  = action
        post[:key] = @options[:login]

        request = post.merge(parameters).collect { |key, value| "UM#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
    end
  end
end

