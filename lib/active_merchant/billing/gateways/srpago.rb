require 'openssl'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SrpagoGateway < Gateway
      self.test_url = 'https://sandbox-api.srpago.com/v1/'
      self.live_url = 'https://example.com/v1'

      self.supported_countries = ['MX']
      self.default_currency = 'MXN'
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.money_format = :dollars
      self.homepage_url = 'http://www.senorpago.com/'
      self.display_name = 'Sr. Pago'
      class_attribute  :cipher, :pkey
      self.cipher = OpenSSL::Cipher.new('AES-256-ECB')
      self.pkey = OpenSSL::PKey::RSA.new("-----BEGIN PUBLIC KEY-----\nMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv0utLFjwHQk+1aLjxl9t\nOjvt/qFD1HfMFzjYa4d3iFKrQtvxaWM/B/6ltPn6+Pez+dOd59zFmzNHg33h8S0p\naZ6wmNv3mwp4hCJttGzFvl2hhw8Z+OU9KwGSXgQ+5FNyRyDLp0qt75ayvV0vV8oX\n0Pgubd/NTHzRKk0ubXO8WVWkNhMdsv0HGrhIMDXAWLAQBzDewmICVH9MIJzjoZym\nR7AuNpefD4hoVK8cBMjZ0xRKSPyd3zI6uJyERcR3+N9nxvg4guShP27cnD9qpLt4\nL6YtU0BU+husFXoHL6Y2CsxyzxT9mtorAGe5oRiTC7Z/S9u7pxGN4iozgmAei0MZ\nVbKows/qa9/q0PPzbF/PHSZKou1DJvsJ2PKY3ZPYAT7/u4x8NRiJ/6cssuzsIPUd\nQ9HBzA1ZBMHkpOmkipu1G7ks/GwTfQJkHPW5xHu1EOYvgv/PHr3BJnCMNYKFvf5c\n4Qd0COnnU3jDel1OKl7lUzr+ioqUedX393D/fszdK4hjvtUjo6ThTRNm3y4avY/r\nm+oLu8sZWpyBm4PfN2xGOnFco9SiyCT03XOEuOXokid6BDMi0aue9LKJaQR+KGVc\n/H2p2d2Yu4GdgXS1vq1syaf7V0QPOmamTOyJRZ45UoLfBRB8nYBGDo0mPR7GIon6\nM8SmGGsTo3V0L+Ni9bNJHa8CAwEAAQ==\n-----END PUBLIC KEY-----\n")
       
      attr_reader :auth
      STANDARD_ERROR_CODE_MAPPING = {}
      
      def initialize(options={})
        requires!(options, :apì_key, :api_secret)
         @auth ={:credentials => Base64.strict_encode64(options[:apì_key]+":"+options[:api_secret]).strip ,:key =>  options[:apì_key]}
        super
      end

      def purchase(money, payment, options={})
        response_login = login
        return response_login unless logged? response_login
        post = {}
        post[:payment] = {}
        post[:payment][:external] = {}
        post[:payment][:external][:transaction] = options[:invoice]
        post[:payment][:external][:application_key] = self.auth[:api_key]
        post[:payment][:origin] = {}
        post[:payment][:origin][:device] = ""
        post[:payment][:origin][:ip]  = options[:ip]
        post[:payment][:origin][:location] = {}
        post[:payment][:origin][:location][:latitude] = "0"
        post[:payment][:origin][:location][:longitude] = "0"
        post[:payment][:reference] = {}
        post[:payment][:reference][:number] = options[:order_id]
        post[:payment][:reference][:description] = options[:description]
        
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        commit(:post,'payment/card', (encrypt post) )
      end


      def void(authorization, options={})
        response_login = login
        return response_login unless logged? response_login
        commit(:get,"operations/apply-reversal/#{authorization}", nil)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { purchase(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((Authorization: Bearer )\w+), '\1[FILTERED]').
          gsub(%r((card\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((card_type\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((autorization_code\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((authorization_code\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((token\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((number\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((type\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((transaction\\?":\\?")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r((affiliation\\?":\\?")[^"\\]*)i, '\1[FILTERED]')
      end
      
      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:total] = {}
        currency = options[:currency] || currency(money)
        post[:total][:amount] = amount(money)
        post[:total][:currency] = currency
        post[:payment][:total] = {}
        post[:payment][:total] = post[:total]
      end

      def add_payment(post, payment, options)
        post[:card] = {}
        post[:card][:holder_name] = payment.first_name + " " + payment.last_name
        post[:card][:type] = named_type(payment.brand)
        number = String.new(payment.number)
        post[:card][:raw] = payment.number
        number[6..11] = "XXXXXX"
        post[:card][:number] = number
        post[:card][:cvv] = payment.verification_value
        year = Date.new(payment.year).strftime("%y")
        month = Date.new(payment.month).strftime("%m")
        post[:card][:expiration] = "#{year}#{month}"
        post[:card][:ip] = options[:ip]
        post[:ecommerce] = post[:card]
      end

      def parse(body)
        JSON.parse(body)
      end
      
      def login 
        if((!self.auth.key? (:connection)) ||  (connection_expired?(self.auth[:connection])))
          response = commit(:post,"/auth/login/application",{:application_bundle =>  'com.cobraonline.SrPago', :login => true})
          if(response.success?)
            if(response.params.key? "connection")
              self.auth[:connection] = {}
              self.auth[:connection] = response.params['connection']
            end
          end
          return response
        end
      end
      
      def commit(method, action, parameters)
        url = (test? ? test_url : live_url)
        post = parameters.to_json unless parameters.nil?
        begin
          response = parse(ssl_request(method, url + action , post, headers(parameters)))
        rescue ResponseError => e
          response = response_error(e.response.body)
        rescue JSON::ParserError
          response = invalid_response_error
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
        response['success']
      end

      def message_from(response)
        response['success']? "Success" : response['error']['message']
      end

      def authorization_from(response)
        if success_from(response)
          if(response.key? "result" )
            if (response['result'].key? "recipe")
              response['result']["recipe"]["transaction"]
            end
          end
        end
      end

      def post_data(action, parameters = {})
      end

      def error_code_from(response)
        unless success_from(response)
          if(response['error']['detail'].nil?)
            return response['error']['code']
          else
            return response['error']['detail']['code']
          end
        end
      end
      
      def encrypt(post)
        data = post.to_json.to_s
        self.cipher.encrypt()
        key =  Array.new(32){[*"A".."Z",*'a'..'z', *"0".."9"].sample}.join
        self.cipher.key = key
        edata = Base64.encode64(self.cipher.update(data) + self.cipher.final())
        ekey = Base64.encode64(self.pkey.public_encrypt(key))
        {key: ekey, data: edata }
      end
      
      def headers(params = nil)
        
        headers = {}
        headers["Content-Type"] = "application/json"
        headers['X-User-Agent'] = "{\"agent\" : \"SrPago/ActiveMerchant #{ActiveMerchant::VERSION}\", \"user_agent\" : \"#{user_agent}\" }"
      
        if(!params.nil? && (params.key? :login))
          headers["Authorization"] = "Basic " + self.auth[:credentials]
        else
          headers["Authorization"] = "Bearer "+ self.auth[:connection]['token']
        end
        headers
      end
      
      
      
      def connection_expired?(connection)
          Date.parse(connection['expires']).past?
      end
      
      def response_error(response)
        begin
          parse(response)
        rescue JSON::ParserError
          invalid_response_error
        end
      end

      def invalid_response_error
        {:success =>  false, :error =>  { :message =>  "Api connection error, invalid response from server"}}.to_json
      end
      
      def named_type(type)
        case type
        when "visa" then "VISA"
        when "master" then "MAST"
        when "american_express" then "AMEX"
        else
          raise "Unhandled credit card brand #{brand}"
        end
      end
      
      def logged?(response_login)
        response_login.nil? || response_login.success?
      end
    end
  end
end
