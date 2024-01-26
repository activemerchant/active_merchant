module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SumUpGateway < Gateway
      self.live_url = 'https://api.sumup.com/v0.1/'

      self.supported_countries = %w(AT BE BG BR CH CL CO CY CZ DE DK EE ES FI FR
                                    GB GR HR HU IE IT LT LU LV MT NL NO PL PT RO
                                    SE SI SK US)
      self.currencies_with_three_decimal_places = %w(EUR BGN BRL CHF CZK DKK GBP
                                                     HUF NOK PLN SEK USD)
      self.default_currency = 'USD'

      self.homepage_url = 'https://www.sumup.com/'
      self.display_name = 'SumUp'

      STANDARD_ERROR_CODE_MAPPING = {
        multiple_invalid_parameters: 'MULTIPLE_INVALID_PARAMETERS'
      }

      def initialize(options = {})
        requires!(options, :access_token, :pay_to_email)
        super
      end

      def purchase(money, payment, options = {})
        MultiResponse.run do |r|
          r.process { create_checkout(money, payment, options) } unless options[:checkout_id]
          r.process { complete_checkout(options[:checkout_id] || r.params['id'], payment, options) }
        end
      end

      def void(authorization, options = {})
        checkout_id = authorization.split('#')[0]
        commit("checkouts/#{checkout_id}", {}, :delete)
      end

      def refund(money, authorization, options = {})
        transaction_id = authorization.split('#').last
        post = money ? { amount: amount(money) } : {}
        add_merchant_data(post, options)

        commit("me/refund/#{transaction_id}", post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer )\w+), '\1[FILTERED]').
          gsub(%r(("pay_to_email\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvv\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def create_checkout(money, payment, options)
        post = {}

        add_merchant_data(post, options)
        add_invoice(post, money, options)
        add_address(post, options)
        add_customer_data(post, payment, options)

        commit('checkouts', post)
      end

      def complete_checkout(checkout_id, payment, options = {})
        post = {}

        add_payment(post, payment, options)

        commit("checkouts/#{checkout_id}", post, :put)
      end

      def add_customer_data(post, payment, options)
        post[:customer_id]      = options[:customer_id]
        post[:personal_details] = {
          email:      options[:email],
          first_name: payment&.first_name,
          last_name:  payment&.last_name,
          tax_id:     options[:tax_id]
        }
      end

      def add_merchant_data(post, options)
        # Required field: pay_to_email
        # Description: Email address of the merchant to whom the payment is made.
        post[:pay_to_email] = @options[:pay_to_email]
      end

      def add_address(post, options)
        post[:personal_details] ||= {}
        if address = (options[:billing_address] || options[:shipping_address] || options[:address])
          post[:personal_details][:address] = {
            city:        address[:city],
            state:       address[:state],
            country:     address[:country],
            line_1:      address[:address1],
            postal_code: address[:zip]
          }
        end
      end

      def add_invoice(post, money, options)
        post[:checkout_reference] = options[:order_id]
        post[:amount]             = amount(money)
        post[:currency]           = options[:currency] || currency(money)
        post[:description]        = options[:description]
      end

      def add_payment(post, payment, options)
        post[:payment_type] = options[:payment_type] || 'card'

        post[:card] = {
          name:         payment.name,
          number:       payment.number,
          expiry_month: format(payment.month, :two_digits),
          expiry_year:  payment.year,
          cvv:          payment.verification_value
        }
      end

      def commit(action, post, method = :post)
        response = api_request(action, post.compact, method)
        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          action.include?('refund') ? { response_code: response.to_s } : response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(succeeded, response)
        )
      end

      def api_request(action, post, method)
        raw_response =
          begin
            ssl_request(method, live_url + action, post.to_json, auth_headers)
          rescue ResponseError => e
            e.response.body
          end
        response = parse(raw_response)
        response = response.is_a?(Hash) ? response.symbolize_keys : response

        return format_errors(response) if raw_response.include?('error_code') && response.is_a?(Array)

        response
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        return true if response == 204

        return false unless %w(PENDING EXPIRED PAID).include?(response[:status])

        response[:transactions].each do |transaction|
          return false unless %w(PENDING CANCELLED SUCCESSFUL).include?(transaction.symbolize_keys[:status])
        end

        true
      end

      def message_from(succeeded, response)
        if succeeded
          return 'Succeeded' if response.is_a?(Integer)

          return response[:status]
        end

        response[:message] || response[:error_message]
      end

      def authorization_from(response)
        return nil if response.is_a?(Integer)

        return response[:id] unless response[:transaction_id]

        [response[:id], response[:transaction_id]].join('#')
      end

      def auth_headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{options[:access_token]}"
        }
      end

      def error_code_from(succeeded, response)
        response[:error_code] unless succeeded
      end

      def format_error(error, key)
        {
          :error_code => error['error_code'],
          key => error['param']
        }
      end

      def format_errors(errors)
        return format_error(errors.first, :message) if errors.size == 1

        return {
          error_code: STANDARD_ERROR_CODE_MAPPING[:multiple_invalid_parameters],
          message: 'Validation error',
          errors: errors.map { |error| format_error(error, :param) }
        }
      end

      def handle_response(response)
        case response.code.to_i
        # to get the response code (204) when the body is nil
        when 200...300
          response.body || response.code
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
