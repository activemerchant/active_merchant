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
        commit('checkouts/' + checkout_id, {}, :delete)
      end

      def refund(money, authorization, options = {})
        transaction_id = authorization.split('#')[-1]
        payment_currency = options[:currency] || currency(money)
        post = money ? { amount: localized_amount(money, payment_currency) } : {}
        add_merchant_data(post, options)

        commit('me/refund/' + transaction_id, post)
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

        commit('checkouts/' + checkout_id, post, :put)
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
        payment_currency = options[:currency] || currency(money)
        post[:checkout_reference] = options[:order_id]
        post[:amount]             = localized_amount(money, payment_currency)
        post[:currency]           = payment_currency
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

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def api_request(action, post, method)
        begin
          raw_response = ssl_request(method, live_url + action, post.to_json, auth_headers)
        rescue ResponseError => e
          raw_response = e.response.body
        end

        response = parse(raw_response)
        # Multiple invalid parameters
        response = format_multiple_errors(response) if raw_response.include?('error_code') && response.is_a?(Array)

        return response.symbolize_keys
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        return false unless %w(PENDING EXPIRED PAID).include?(response[:status])

        response[:transactions].each do |transaction|
          return false unless %w(PENDING CANCELLED SUCCESSFUL).include?(transaction.symbolize_keys[:status])
        end

        true
      end

      def message_from(response)
        return response[:status] if success_from(response)

        response[:message] || response[:error_message]
      end

      def authorization_from(response)
        return response[:id] unless response[:transaction_id]

        [response[:id], response[:transaction_id]].join('#')
      end

      def auth_headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{options[:access_token]}"
        }
      end

      def error_code_from(response)
        response[:error_code] unless success_from(response)
      end

      def format_multiple_errors(responses)
        errors = responses.map do |response|
          { error_code: response['error_code'], param: response['param'] }
        end

        {
          error_code: STANDARD_ERROR_CODE_MAPPING[:multiple_invalid_parameters],
          message: 'Validation error',
          errors: errors
        }
      end
    end
  end
end
