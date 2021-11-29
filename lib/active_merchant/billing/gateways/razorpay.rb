module ActiveMerchant #:nodoc:
    module Billing #:nodoc:
      class RazorpayGateway < Gateway
        self.live_url = 'https://api.razorpay.com/v1'
        self.supported_countries = ['IN']
        self.default_currency = 'INR'
        self.supported_cardtypes = [:visa, :mastercard, :maestro, :rupay, :amex, :diners_club, :bajaj]
  
        self.homepage_url = 'http://razorpay.com'
        self.display_name = 'Razorpay'
        self.money_format = :cents
  
        STANDARD_ERROR_CODE_MAPPING = {}
  
        def initialize(options={})
          requires!(options, :key_id, :key_secret)
          super
        end

        def create_order(money, options={})
          requires!(options, :currency)
          post = {}
          add_amount(post, money)
          post[:currency] = (options[:currency] || currency(money))
          post[:receipt] = options[:order_id] if options[:order_id]
          post[:notes] = options[:notes] if options[:notes]
          post[:partial_payment] = options[:partial_payment] if options[:partial_payment]
          commit(:post, 'order', {}, post)
        end

        def get_payment(payment_id, options={})
          return Response.new(false, 'Payment ID is mandatory') if payment_id.empty?
          parameters = {}
          parameters[:authorization_id] = payment_id
          commit(:get, 'fetch', parameters)
        end

        def get_payments_by_order_id(order_id, options={})
          return Response.new(false, 'Order ID is mandatory') if order_id.empty?
          parameters = {}
          parameters[:authorization_id] = order_id
          commit(:get, 'fetch_payments_by_order', parameters)
        end
  
        def capture(money, payment_id, options={})
          return Response.new(false, 'Payment ID is mandatory') if payment_id.empty?
          post = {}
          parameters = {}
          add_amount(post, money)
          post[:currency] = (options[:currency] || currency(money))
          parameters[:authorization_id] = payment_id
          commit(:post, 'capture', parameters, post)
        end
  
        def refund(payment_id, options={})
          parameters = {}
          post = {}
          parameters[:authorization_id] = payment_id
          add_amount(post, options[:amount]) if options[:amount]
          commit(:post, 'refund', parameters, post)
        end
  
        def void(authorization, options={})
          Response.new(true, 'Razorpay does not support void api')
        end
  
        def supports_scrubbing?
          false
        end
  
        private
  
        def add_amount(post, money)
          post[:amount] = amount(money)
        end
  
        def parse(body)
          JSON.parse(body)
        end

        def endpoint(action, parameters)
          case action
          when 'order'
            'orders'
          when 'refund'
            "payments/#{parameters[:authorization_id]}/refund"
          when 'capture'
            "payments/#{parameters[:authorization_id]}/capture"
          when 'fetch'
            "payments/#{parameters[:authorization_id]}"
          when 'fetch_payments_by_order'
            "orders/#{parameters[:authorization_id]}/payments"
          end
        end

        def url(action, parameters)
          "#{live_url}/#{endpoint(action, parameters)}"
        end
  
        def api_request(method, endpoint, body = nil)
          raw_response = ssl_request(method, endpoint, body, headers)
          parse(raw_response)
        rescue ActiveMerchant::ResponseError => e
          return parse(e.response.body)
        end
  
        def headers
          {
            'Content-Type' => 'application/json',
            'Authorization' => 'Basic ' + Base64.strict_encode64("#{@options[:key_id]}:#{@options[:key_secret]}").strip
          }
        end
  
        def commit(method, action, parameters, body={})
          url = url(action, parameters)
          post = post_data(method, body)
  
          response = api_request(method, url, post)
  
          Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            avs_result: nil,
            cvv_result: nil,
            test: test?,
            error_code: error_code_from(response)
          )
        end
  
        def success_from(response)
          response['error_code'].nil? && response['error'].nil?
        end
  
        def message_from(response)
          if success_from(response)
            'OK'
          elsif response['error']
            response['error']['description']
          elsif response['error_description']
            response['error_description']
          end
        end
  
        def authorization_from(response)
          response['id']
        end

        def post_data(method, parameters={})
          if method == :get || method == :delete
            nil
          else
            parameters.to_json
          end
        end
  
        def error_code_from(response)
          unless success_from(response)
            if response['error']
              if response['error']['reason'] != "NA"
                response['error']['reason']
              else
                response['error']['code']
              end
            elsif response["error_reason"]
              response["error_reason"]
            elsif response["error_code"]
              response["error_code"]
            else
              'BAD_REQUEST_ERROR'
            end
          end
        end
      end
    end
  end
