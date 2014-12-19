module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayOnlinePaymentsGateway < Gateway
      self.live_url = 'https://api.worldpay.com/v1/'
      #self.live_url = self.test_url = 'https://api.worldpay.com/v1/'

      self.default_currency = 'GBP'
      self.money_format = :cents

      self.supported_countries = %w(HK US GB AU AD BE CH CY CZ DE DK ES FI FR GI GR HU IE IL IT LI LU MC MT NL NO NZ PL PT SE SG SI SM TR UM VA)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :laser, :switch]

      self.homepage_url = 'http://online.worldpay.com'
      self.display_name = 'Worldpay Online Payments'

      CARD_CODES = {
          'visa'             => 'VISA-SSL',
          'master'           => 'ECMC-SSL',
          'discover'         => 'DISCOVER-SSL',
          'american_express' => 'AMEX-SSL',
          'jcb'              => 'JCB-SSL',
          'maestro'          => 'MAESTRO-SSL',
          'laser'            => 'LASER-SSL',
          'diners_club'      => 'DINERS-SSL',
          'switch'           => 'MAESTRO-SSL'
      }

      #VISA, MASTERCARD, BHS, IKEA, AMEX, DINERS, DANKORT, DISCOVER, JCB, AIRPLUS, UATP, MAESTRO, LASER, UNKNOWN, VISA_CREDIT, VISA_DEBIT, MASTERCARD_CREDIT, MASTERCARD_DEBIT, CARTEBLEUE;

      def initialize(options={})
        requires!(options, :client_key)
        requires!(options, :service_key)
        @client_key = options[:client_key]
        @service_key = options[:service_key]
        super
      end

      def authorize(money, creditcard, options={})

        token_response = create_token(true, creditcard.first_name+' '+creditcard.last_name, creditcard.month, creditcard.year, creditcard.number, creditcard.verification_value)
        token_response = parse(token_response)

        if token_response['token']

          #add_creditcard(post, creditcard, options)

          Response.new(true,
                       "SUCCESS",
                       {},
                       :test => @service_key[0]=="T" ? true : false,
                       :authorization => token_response['token']
          )
        else
          Response.new(false,
                       "FAILURE",
                       token_response,
                       :test => @service_key[0]=="T" ? true : false
          )
        end

      end

      def capture(money, authorization, options={})
          post = create_post_for_auth_or_purchase(authorization, money, options)
          commit(:post, 'orders', post, options)
      end


      def purchase(money, creditcard, options={})

        auth = authorize(money, creditcard, options)
        if (auth.authorization)
          post = create_post_for_auth_or_purchase(auth.authorization, money, options)
          commit(:post, 'orders', post, options)
        end

      end

      def refund(money, orderCode, options={})
        commit(:post, "orders/#{CGI.escape(orderCode)}/refund", {}, options)
      end

      def void(orderCode, options={})
        commit(:post, "orders/#{CGI.escape(orderCode)}/refund", {}, options)
      end

      def verify(creditcard, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(50, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
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

        url = self.live_url+'/tokens'

        #xmr = ssl_post(url, request, 'Content-Type' => 'text/xml', 'Authorization' => encoded_credentials)
        token_response = ssl_post(url, obj.to_json, 'Content-Type' => 'application/json', 'Authorization' => @service_key)

        token_response
      end


      def create_post_for_auth_or_purchase(token, money, options)
        post = {}

        add_amount(post, money, options, true)

        post = {
          "token" => token,
          "orderDescription" => options[:description],
          "amount" => money,
          "currencyCode" => options[:currency],
          "name" => options[:address][:name],
=begin
          "customerIdentifiers" => {
              "product-category"=>"fruits",
              "product-quantity"=>"3",
              "product-quantity"=>"5",
              "product-name"=>"orange"
          },
=end
          "billingAddress" => {
              "address1"=>options[:address][:address1],
              "address2"=>options[:address][:address2],
              "address3"=>"",
              "postalCode"=>options[:address][:zip],
              "city"=>options[:address][:city],
              "state"=>options[:address][:state],
              "countryCode"=>options[:address][:country]
          },
          "customerOrderCode" => options[:order_id],
          "orderType" => "ECOM"
        }


        post
      end


      def add_amount(post, money, options, include_currency = false)
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency.downcase if include_currency
      end

      def add_customer_data(post, options)
      end

      def add_address(post, options)
        return unless post[:card] && post[:card].kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          post[:card][:address_line1] = address[:address1] if address[:address1]
          post[:card][:address_line2] = address[:address2] if address[:address2]
          post[:card][:address_country] = address[:country] if address[:country]
          post[:card][:address_zip] = address[:zip] if address[:zip]
          post[:card][:address_state] = address[:state] if address[:state]
          post[:card][:address_city] = address[:city] if address[:city]
        end
      end

      def add_creditcard(post, creditcard, options)
        card = {}
        if creditcard.respond_to?(:number)
          if creditcard.respond_to?(:track_data) && creditcard.track_data.present?
            card[:swipe_data] = creditcard.track_data
          else
            card[:number] = creditcard.number
            card[:exp_month] = creditcard.month
            card[:exp_year] = creditcard.year
            card[:cvc] = creditcard.verification_value if creditcard.verification_value?
            card[:name] = creditcard.name if creditcard.name
          end

          post[:card] = card
          add_address(post, options)
        elsif creditcard.kind_of?(String)
          if options[:track_data]
            card[:swipe_data] = options[:track_data]
          else
            card = creditcard
          end
          post[:card] = card
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      def parse(body)
        if (body.class==NilClass)
          body = {}
        else
          body = JSON.parse(body)
        end
        body
      end

      def headers(options = {})
        headers = {
            "Authorization" => @service_key,
            "Content-Type" => 'application/json',
            "User-Agent" => "Worldpay/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
            "X-Worldpay-Client-User-Agent" => user_agent,
            "X-Worldpay-Client-User-Metadata" => {:ip => options[:ip]}.to_json
        }
        headers
      end

      def commit(method, url, parameters=nil, options = {})

        raw_response = response = nil
        success = false
        begin

          raw_response = ssl_request(method, self.live_url + url, parameters.to_json, headers(options))


          response = parse(raw_response)

          success = !response.key?("error")
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError => e
          if (/orders\/(.*)\/refund/.match(url))
            success = true
            response = {}
          else
            response = json_error(raw_response)
          end
        end


        Response.new(success,
                     success ? "Transaction approved" : response["message"],
                     response,
                     :test => @service_key[0]=="T" ? true : false,
                     :authorization => success ? response["orderCode"] : response["message"],
                     :avs_result => {},
                     :cvv_result => {},
                     :error_code => success ? nil : response["customCode"]
        )
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

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          elsif value.is_a?(Array)
            value.map { |v| "#{key}[]=#{CGI.escape(v.to_s)}" }.join("&")
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end
    end
  end
end
