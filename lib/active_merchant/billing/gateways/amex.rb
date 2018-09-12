module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AmexGateway < Gateway
      attr_reader :currency, :api_version, :username, :password
      DEFAULT_URL = 'https://gateway-na.americanexpress.com/api/rest'.freeze

      def initialize(options = {})
        requires!(options, :currency, :username, :password, :api_version)
        @currency, @username, @password, @api_version = options.values_at(:currency, :username, :password, :api_version)
        super
      end

      def purchase(amount, credit_card_or_token, options = {})
        if credit_card_or_token.is_a?(ActiveMerchant::Billing::CreditCard)
          credit_card_or_token = get_token(credit_card_or_token)
        end
        commit(:put, transaction_endpoint(options), post_data(pay_body(amount, credit_card_or_token, options)), request_headers)
      end

      def refund(amount, options = {})
        commit(:put, transaction_endpoint(options), post_data(refund_body(amount, options)), request_headers)
      end

      def store(credit_card)
        commit(:post, tokenization_endpoint, post_data(store_body(credit_card)), request_headers)
      end

      def update_card(credit_card)
        commit(:post, tokenization_endpoint, post_data(update_body(credit_card)), request_headers)
      end

      def delete_token(credit_card_or_token)
        if credit_card_or_token.is_a?(ActiveMerchant::Billing::CreditCard)
          credit_card_or_token = get_token(credit_card_or_token)
        end
        commit(:delete, delete_token_endpoint(credit_card_or_token), post_data({}), request_headers)
      end

      # Authorize and Capture cannot be used with the Amex Gateway when pay is
      # enabled. Pay is enabled in our environment and because of this we could
      # not test these methods.
      # def authorize(amount, credit_card_or_token, options = {})
      #   if credit_card_or_token.is_a?(ActiveMerchant::Billing::CreditCard)
      #     credit_card_or_token = store(credit_card_or_token).params['token']
      #   end
      #   commit(:put, transaction_endpoint(options), post_data(authorize_body(amount, credit_card_or_token)), request_headers)
      # end

      # def capture(amount, options = {})
      #   commit(:put, transaction_endpoint(options), post_data(capture_body(amount)), request_headers)
      # end

      def void(target_transaction_id, options = {})
        commit(:put, transaction_endpoint(options), post_data(void_body(target_transaction_id, options)), request_headers)
      end

      def verify(options)
        commit(:put, transaction_endpoint(options), post_data(verify_body(options)), request_headers)
      end

      def find_transaction(options)
        commit(:get, transaction_endpoint(options), post_data({}), request_headers)
      end

      private

      def post_data(parameters = {})
        return nil if parameters.empty?
        JSON.generate(parameters)
      end

      def pay_body(amount, token, options)
        body = {
                 apiOperation: 'PAY',
                 order: {
                   amount: amount,
                   currency: currency
                 },
                 sourceOfFunds: {
                   token: token
                 }
        }
        add_additonal_params(body, options)
      end

      def refund_body(amount, options)
        body = {
          apiOperation: 'REFUND',
          transaction: {
            amount:    amount,
            currency:  currency
          }
        }
        body[:transaction].merge!(options[:body][:transaction]) if options.key?(:body) && !options[:body][:transaction].nil?
        body
      end

      def authorize_body(amount, token)
        {
          apiOperation: 'AUTHORIZE',
          order: {
            amount:    amount,
            currency:  currency
          },
          sourceOfFunds: {
            token: token
          }
        }
      end

      def capture_body(amount, options)
        {
          apiOperation: 'CAPTURE',
          transaction: {
            amount:    amount,
            currency:  currency
          }
        }
      end

      def void_body(target_transaction_id, options)
        body = {
                  apiOperation: 'VOID',
                  transaction: {
                    targetTransactionId: target_transaction_id
                  }
                }
        add_additonal_params(body, options)
      end

      def verify_body(options)
        body = {
          apiOperation: 'VERIFY',
          order: {
            currency: currency
          },
          sourceOfFunds: {
            token: options[:token]
          }
        }
        add_additonal_params(body, options)
      end

      def store_body(credit_card)
        {
          sourceOfFunds: {
            type: 'CARD',
            provided: {
              card: {
                expiry: {
                  month: credit_card.month,
                  year:  convert_year(credit_card.year)
                },
                number:       credit_card.number,
                securityCode: credit_card.verification_value
              }
            }
          }
        }
      end

      def update_body(credit_card)
        {
          sourceOfFunds: {
            token: get_token(credit_card),
            type: 'CARD',
            provided: {
              card: {
                expiry: {
                  month: credit_card.month,
                  year:  convert_year(credit_card.year)
                },
                number:       credit_card.number,
                securityCode: credit_card.verification_value
              }
            }
          }
        }
      end

      def get_token(credit_card)
        store(credit_card).params['token']
      end

      def tokenization_endpoint
        "#{version_path}/merchant/#{username}/token"
      end

      def transaction_endpoint(options)
        "#{version_path}/merchant/#{username}/order/#{options[:order_id]}/transaction/#{options[:transaction_id]}"
      end

      def delete_token_endpoint(token)
        "#{version_path}/merchant/#{username}/token/#{token}"
      end

      def version_path
        "#{DEFAULT_URL}/version/#{api_version}"
      end

      def basic_auth
        Base64.strict_encode64("merchant.#{username}:#{password}")
      end

      def request_headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
      end

      def convert_year(year)
        year.to_s[-2, 2]
      end

      def add_additonal_params(body, options)
        adjust_order_params(body, options)
        body[:shipping] = options[:body][:shipping] if options.key?(:body) && !options[:body][:shipping].nil?
        body
      end

      def adjust_order_params(body, options)
        return if !options.key?(:body) || options[:body][:order].nil?
        if body.key?(:order)
          body[:order].merge!(options[:body][:order])
        else
          body[:order] = options[:body][:order]
        end
      end

      def parse(body)
        return nil if body.blank?
        JSON.parse(body)
      end

      def success_from(response)
        response['result'] == 'SUCCESS'
      end

      def message_from(response)
        response['response']
      end

      def authorization_from(response)
        response['authorizationResponse']
      end

      def commit(method, endpoint, data, headers)
        response = parse(ssl_request(method, endpoint, data, headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: /TEST/.match(username)
        )
      end

      def handle_response(response)
        case response.code.to_i
        when 200...500
          response.body
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
