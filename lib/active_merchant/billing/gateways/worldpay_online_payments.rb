module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayOnlinePaymentsGateway < Gateway
      self.live_url =  'https://api.worldpay.com/v1/'

      self.default_currency = 'GBP'

      self.money_format = :cents

      self.supported_countries = %w(HK US GB BE CH CZ DE DK ES FI FR GR HU IE IT LU MT NL NO PL PT SE SG TR)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :laser, :switch]

      self.homepage_url = 'http://online.worldpay.com'
      self.display_name = 'Worldpay Online Payments'

      def initialize(options={})
        requires!(options, :client_key, :service_key)
        @client_key = options[:client_key]
        @service_key = options[:service_key]
        super
      end

      def authorize(money, credit_card, options={})
        response = create_token(true, credit_card.first_name+' '+credit_card.last_name, credit_card.month, credit_card.year, credit_card.number, credit_card.verification_value)
        if response.success?
          options[:authorizeOnly] = true
          post = create_post_for_auth_or_purchase(response.authorization, money, options)
          response = commit(:post, 'orders', post, {}, 'authorize')
        end
        response
      end

      def capture(money, authorization, options={})
        if authorization
          commit(:post, "orders/#{CGI.escape(authorization)}/capture", {"captureAmount"=>money}, options, 'capture')
        else
          Response.new(false,
            'FAILED',
            'FAILED',
            :test => test?,
            :authorization => false,
            :avs_result => {},
            :cvv_result => {},
            :error_code => false
          )
        end
      end

      def purchase(money, credit_card, options={})
        response = create_token(true, credit_card.first_name+' '+credit_card.last_name, credit_card.month, credit_card.year, credit_card.number, credit_card.verification_value)
        if response.success?
          post = create_post_for_auth_or_purchase(response.authorization, money, options)
          response = commit(:post, 'orders', post, options, 'purchase')
        end
        response
      end

      def refund(money, orderCode, options={})
        obj = money ? {"refundAmount" => money} : {}
        commit(:post, "orders/#{CGI.escape(orderCode)}/refund", obj, options, 'refund')
      end

      def void(orderCode, options={})
        response = commit(:delete, "orders/#{CGI.escape(orderCode)}", nil, options, 'void')
        if !response.success? && (response.params && response.params['customCode'] != 'ORDER_NOT_FOUND')
          response = refund(nil, orderCode)
        end
        response
      end

      def verify(credit_card, options={})
        authorize(0, credit_card, options)
      end

      private

      def create_token(reusable, name, exp_month, exp_year, number, cvc)
        obj = {
          "reusable"=> reusable,
          "paymentMethod"=> {
            "type"=> "Card",
            "name"=> name,
            "expiryMonth"=> exp_month,
            "expiryYear"=> exp_year,
            "cardNumber"=> number,
            "cvc"=> cvc
          },
          "clientKey"=> @client_key
        }
        token_response = commit(:post, 'tokens', obj, {'Authorization' => @service_key}, 'token')
        token_response
      end

      def create_post_for_auth_or_purchase(token, money, options)
      {
        "token" => token,
        "orderDescription" => options[:description] || 'Worldpay Order',
        "amount" => money,
        "currencyCode" => options[:currency] || default_currency,
        "name" => options[:billing_address]&&options[:billing_address][:name] ? options[:billing_address][:name] : '',
        "billingAddress" => {
          "address1"=>options[:billing_address]&&options[:billing_address][:address1] ? options[:billing_address][:address1] : '',
          "address2"=>options[:billing_address]&&options[:billing_address][:address2] ? options[:billing_address][:address2] : '',
          "address3"=>"",
          "postalCode"=>options[:billing_address]&&options[:billing_address][:zip] ? options[:billing_address][:zip] : '',
          "city"=>options[:billing_address]&&options[:billing_address][:city] ? options[:billing_address][:city] : '',
          "state"=>options[:billing_address]&&options[:billing_address][:state] ? options[:billing_address][:state] : '',
          "countryCode"=>options[:billing_address]&&options[:billing_address][:country] ? options[:billing_address][:country] : ''
          },
          "customerOrderCode" => options[:order_id],
          "orderType" => "ECOM",
          "authorizeOnly" => options[:authorizeOnly] ? true : false
        }
      end

      def parse(body)
        body ? JSON.parse(body) : {}
      end

      def headers(options = {})
        headers = {
          "Authorization" => @service_key,
          "Content-Type" => 'application/json',
          "User-Agent" => "Worldpay/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "X-Worldpay-Client-User-Agent" => user_agent,
          "X-Worldpay-Client-User-Metadata" => {:ip => options[:ip]}.to_json
        }
        if options['Authorization']
          headers['Authorization'] = options['Authorization']
        end
        headers
      end

      def commit(method, url, parameters=nil, options = {}, type = false)
        raw_response = response = nil
        success = false
        begin
          json = parameters ? parameters.to_json : nil

          raw_response = ssl_request(method, self.live_url + url, json, headers(options))

          if (raw_response != '')
            response = parse(raw_response)
            if type == 'token'
              success = response.key?('token')
            else
              if response.key?('httpStatusCode')
                success = false
              else
                if type == 'authorize' && response['paymentStatus'] == 'AUTHORIZED'
                  success = true
                elsif type == 'purchase' && response['paymentStatus'] == 'SUCCESS'
                  success = true
                elsif type == 'capture' || type=='refund' || type=='void'
                  success = true
                end
              end
            end
          else
            success = true
            response = {}
          end

        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError => e
          response = json_error(raw_response)
        end

        if response["orderCode"]
          authorization = response["orderCode"]
        elsif response["token"]
          authorization = response["token"]
        else
          authorization = response["message"]
        end

        Response.new(success,
          success ? "SUCCESS" : response["message"],
          response,
          :test => test?,
          :authorization => authorization,
          :avs_result => {},
          :cvv_result => {},
          :error_code => success ? nil : response["customCode"]
        )
      end

      def test?
        @service_key[0]=="T" ? true : false
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Worldpay Online Payments API.  Please contact techsupport.online@worldpay.com if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def handle_response(response)
        response.body
      end

    end
  end
end
