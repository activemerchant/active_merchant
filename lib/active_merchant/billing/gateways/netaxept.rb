require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetaxeptGateway < Gateway
      TEST_URL = 'https://epayment-test.bbs.no/'
      LIVE_URL = 'https://epayment.bbs.no/'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['NO', 'DK', 'SE', 'FI']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.betalingsterminal.no/Netthandel-forside/'
      
      # The name of the gateway
      self.display_name = 'BBS Netaxept'
      
      self.money_format = :cents
      
      self.default_currency = 'NOK'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        add_credentials(post, options)
        add_transaction(post, options)
        add_order(post, money, options)
        add_creditcard(post, creditcard)
        commit('Sale', post)
      end                       

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        add_credentials(post, options)
        add_transaction(post, options)
        add_order(post, money, options)
        add_creditcard(post, creditcard)
        commit('Auth', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization, money)
        commit('Capture', post, false)
      end

      def credit(money, authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization, money)
        commit('Credit', post, false)
      end

      def void(authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization)
        commit('Annul', post, false)
      end

      def test?
        @options[:test] || Base.gateway_mode == :test
      end

    
      private
      
      def add_credentials(post, options)
        post[:merchantId] = @options[:login]
        post[:token] = @options[:password]
      end
      
      def add_authorization(post, authorization, money=nil)
        post[:transactionId] = authorization
        post[:transactionAmount] = amount(money) if money
      end
      
      def add_transaction(post, options)
        post[:transactionId] = generate_transaction_id(options)
        post[:serviceType] = 'M'
        post[:redirectUrl] = 'http://example.com'
      end
      
      def add_order(post, money, options)
        post[:orderNumber] = options[:order_id]
        post[:amount] = amount(money)
        post[:currencyCode] = (options[:currency] || currency(money))
      end
      
      CARD_TYPE_PREFIXES = {
        'visa' => 'v',
        'master' => 'm',
        'american_express' => 'a',
      }
      def add_creditcard(post, creditcard)
        brand = Gateway.card_brand(creditcard)
        prefix = CARD_TYPE_PREFIXES[brand]
        unless prefix
          raise ArgumentError.new("Card type #{brand} not supported.")
        end

        post[:creditcard] = {}
        post[:creditcard][:"#{prefix}a"] = creditcard.number
        post[:creditcard][:"#{prefix}m"] = format(creditcard.month, :two_digits)
        post[:creditcard][:"#{prefix}y"] = format(creditcard.year, :two_digits)
        post[:creditcard][:"#{prefix}c"] = creditcard.verification_value
      end
      
      def commit(action, parameters, setup=true)
        parameters[:action] = action

        response = {:success => false}

        catch(:exception) do
          if setup
            commit_transaction_setup(response, parameters)
            commit_payment_details(response, parameters)
            commit_process_setup(response, parameters)
          end
          commit_transaction(response, parameters)
          response[:success] = true
        end
        
        Response.new(response[:success], response[:message], response, :test => test?, :authorization => response[:authorization])
      end
      
      def commit_transaction_setup(response, parameters)
        response[:setup] = parse(ssl_get(build_url("REST/Setup.aspx", pick(parameters, :merchantId, :token, :serviceType, :amount, :currencyCode, :redirectUrl, :orderNumber, :transactionId))))
        process(response, :setup)
      end
      
      def commit_payment_details(response, parameters)
        data = encode(parameters[:creditcard].merge(:BBSePay_transaction => response[:setup]['SetupString']))
        response[:paymentDetails] = parse(ssl_post(build_url("terminal/default.aspx"), data), false)
        process(response, :paymentDetails)
      end
      
      def commit_process_setup(response, parameters)
        result = ssl_get(build_url("REST/ProcessSetup.aspx", pick(parameters, :merchantId, :token, :transactionId).merge(:transactionString => response[:paymentDetails][:result])))
        response[:processSetup] = parse(result)
        process(response, :processSetup)
      end
      
      def commit_transaction(response, parameters)
        result = ssl_get(build_url("REST/#{parameters[:action]}.aspx", pick(parameters, :merchantId, :token, :transactionId, :transactionAmount)))
        response[:action] = parse(result)
        process(response, :action)
      end

      def process(response, step)
        if response[step][:container] =~ /Exception|Error/
          response[:message] = response[step]['Message']
          throw :exception
        else
          message = (response[step]['ResponseText'] || response[step]['ResponseCode'])
          response[:message] = (message || response[:message])
          
          response[:authorization] = response[step]['TransactionId']
        end
      end
      
      def parse(result, expects_xml=true)
        if expects_xml || /^</ =~ result
          doc = REXML::Document.new(result)
          extract_xml(doc.root).merge(:container => doc.root.name)
        else
          {:result => result}
        end
      end
      
      def extract_xml(element)
        if element.has_elements?
          hash = {}
          element.elements.each do |e|
            hash[e.name] = extract_xml(e)
          end
          hash
        else
          element.text
        end
      end
      
      def url
        (test? ? TEST_URL : LIVE_URL)
      end
      
      def generate_transaction_id(options)
        Digest::MD5.hexdigest("#{options.inspect}+#{Time.now}+#{rand}")
      end
      
      def pick(hash, *keys)
        keys.inject({}){|h,key| h[key] = hash[key] if hash[key]; h}
      end
      
      def build_url(base, parameters=nil)
        url = "#{test? ? TEST_URL : LIVE_URL}"
        url << base
        if parameters
          url << '?'
          url << encode(parameters)
        end
        url
      end
      
      def encode(hash)
        hash.collect{|(k,v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
      end
      
      class Response < Billing::Response
        attr_reader :error_detail
        def initialize(success, message, raw, options)
          super
          unless success
            @error_detail = raw[:processSetup]['Result']['ResponseText'] if raw[:processSetup] && raw[:processSetup]['Result']
          end
        end
      end
    end
  end
end

