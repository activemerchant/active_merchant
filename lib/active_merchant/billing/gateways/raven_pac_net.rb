module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RavenPacNetGateway < Gateway
      self.test_url = 'https://raven.pacnetservices.com/realtime/'
      self.live_url = 'https://raven.pacnetservices.com/realtime/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.money_format = :cents

      self.default_currency = 'USD'

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.pacnetservices.com/'

      # The name of the gateway
      self.display_name = 'Raven PacNet'

      def initialize(options = {})
        requires!(options, :user, :secret, :prn)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)
        add_currency_code(post, money, options)
        add_address(post, options)
        post['PRN'] = @options[:prn]

        commit('cc_preauth', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_currency_code(post, money, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        post['PRN'] = @options[:prn]

        commit('cc_debit', money, post)
      end
      
      def void(authorization, options = {})
        post = {}
        post['TrackingNumber'] = authorization
        post['PymtType'] = options[:pymt_type] || 'cc_debit'

        commit('void', nil, post)
      end
      
      def capture(money, authorization, options = {})
        post = {}
        post['PreauthNumber'] = authorization
        post['PRN'] = @options[:prn]
        add_currency_code(post, money, options)
        
        commit('cc_settle', money, post)
      end

      def refund(money, template_number, options = {})
        post = {}
        post['PRN'] = @options[:prn]
        post['TemplateNumber'] = template_number
        add_currency_code(post, money, options)
        
        commit('cc_refund', money, post)
      end

      private

      def add_creditcard(post, creditcard)
        post['CardNumber'] = creditcard.number
        post['Expiry'] = expdate(creditcard)
        post['CVV2'] = creditcard.verification_value if creditcard.verification_value
      end

      def add_currency_code(post, money, options)
        post['Currency'] = options[:currency] || currency(money)
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post['BillingStreetAddressLineOne']   = address[:address1].to_s
          post['BillingStreetAddressLineFour']  = address[:address2].to_s
          post['BillingPostalCode']             = address[:zip].to_s
        end

        # if address = options[:shipping_address]
        #   post[:ship_to_first_name] = address[:first_name].to_s
        #   post[:ship_to_last_name] = address[:last_name].to_s
        #   post[:ship_to_address] = address[:address1].to_s
        #   post[:ship_to_company] = address[:company].to_s
        #   post[:ship_to_phone]   = address[:phone].to_s
        #   post[:ship_to_zip]     = address[:zip].to_s
        #   post[:ship_to_city]    = address[:city].to_s
        #   post[:ship_to_country] = address[:country].to_s
        #   post[:ship_to_state]   = address[:state].blank?  ? 'n/a' : address[:state]
        # end
      end

      def parse(body)
        Hash[body.split('&').map{|x| x.split('=').map{|x| CGI.unescape(x)}}]
      end

      def commit(action, money, parameters)
        parameters['Amount'] = amount(money) unless action == 'void'
        
        url = self.live_url + endpoint(action)
                
        data = ssl_post url, post_data(action, parameters)

        response = parse(data)
        response[:action] = action
                                
        message = message_from(response)

        test_mode = test? || message =~ /TESTMODE/
        
        Response.new(success?(response), message, response,
          :test => test_mode,
          :authorization => response['TrackingNumber'],
          :fraud_review => fraud_review?(response),
          :avs_result => { :postal_match => response['AVSPostalResponseCode'], :street_match => response['AVSAddressResponseCode'] },
          :cvv_result => response['CVV2ResponseCode']
        )        
      end
      
      def endpoint(action)
        return 'void' if action == 'void'
        'submit'
      end
      
      # response['FraudScore'] is a percentage from 0.00 to 100.00
      # To invoke the fraud scoring mechanism you need to provide at least an IP address, 
      # a billing city and a billing country. Providing additional information will improve 
      # the reliability of the fraud score. 
      # The complete set of fields used to determine the fraud score are:
      # 
      # CardIssuerName
      # CardIssuerPhone
      # CustomerIP
      # BillingCity
      # BillingRegion
      # BillingPostal
      # BillingCountry
      # ShipToCity
      # ShipToRegion
      # ShipToPostal
      # ShipToCountry
      
      def fraud_review?(response)
         # response['FraudScore']
        false
      end

      def success?(response)
        if %w(cc_settle cc_debit cc_preauth cc_refund).include?(response[:action])
          !response['ApprovalCode'].nil? and response['ErrorCode'].nil? and response['Status'] == 'Approved'
        elsif response[:action] = 'void'
          !response['ApprovalCode'].nil? and response['ErrorCode'].nil? and response['Status'] == 'Voided'
        end
      end

      def message_from(response)
        return response['Message'] if response['Message']
        
        if response['Status'] == 'Approved'
          "This transaction has been approved"
        elsif response['Status'] == 'Declined'
          "This transaction has been declined"
        elsif response['Status'] == 'Voided'
          "This transaction has been voided"
        else
          response['Status']
        end
      end

      def post_data(action, parameters = {})
        post = {}

        post['PymtType']      = action
        post['RAPIVersion']   = '2'
        post['UserName']      = @options[:user]
        post['Timestamp']     = Time.now.strftime("%Y-%m-%dT%H:%M:%S.Z")
        post['RequestID']     = (0...21).map{(65+rand(26)).chr}.join.downcase
        post['Signature']     = signature(action, post, parameters)

        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
      
      def signature(action, post, parameters = {})
        string = if %w(cc_settle cc_debit cc_preauth cc_refund).include?(action)
          post['UserName'] + post['Timestamp'] + post['RequestID'] + post['PymtType'] + parameters['Amount'].to_s + parameters['Currency']
        elsif action == 'void'
          post['UserName'] + post['Timestamp'] + post['RequestID'] + parameters['TrackingNumber']
        else
          post['UserName']
        end
        Digest::HMAC.hexdigest(string, @options[:secret], Digest::SHA1)
      end
      
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
      
    end
  end
end

