module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CheckoutV2Gateway < Gateway
      self.display_name = 'Checkout.com Unified Payments'
      self.homepage_url = 'https://www.checkout.com/'
      self.live_url = 'https://api.checkout.com'
      self.test_url = 'https://api.sandbox.checkout.com'

      self.supported_countries = ['AD', 'AE', 'AT', 'BE', 'BG', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FO', 'FI', 'FR', 'GB', 'GI', 'GL', 'GR', 'HR', 'HU', 'IE', 'IS', 'IL', 'IT', 'LI', 'LT', 'LU', 'LV', 'MC', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SI', 'SM', 'SK', 'SJ', 'TR', 'VA']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :maestro, :discover]

      def initialize(options = {})
        requires!(options, :secret_key)
        super
      end

      def purchase(amount, payment_method, options = {})
        multi = MultiResponse.run do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process { capture(amount, r.authorization, options) }
        end

        merged_params = multi.responses.map(&:params).reduce({}, :merge)
        succeeded = success_from(merged_params)

        response(:purchase, succeeded, merged_params)
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        post[:capture] = false
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_transaction_data(post, options)
        add_3ds(post, options)

        commit(:authorize, post)
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)

        commit(:capture, post, authorization)
      end

      def void(authorization, _options = {})
        post = {}
        commit(:void, post, authorization)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)

        commit(:refund, post, authorization)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: )[^\\]*/i, '\1[FILTERED]').
          gsub(/("number\\":\\")\d+/, '\1[FILTERED]').
          gsub(/("cvv\\":\\")\d+/, '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = localized_amount(money, options[:currency])
        post[:reference] = options[:order_id]
        post[:currency] = options[:currency] || currency(money)
        if options[:descriptor_name] || options[:descriptor_city]
          post[:billing_descriptor] = {}
          post[:billing_descriptor][:name] = options[:descriptor_name] if options[:descriptor_name]
          post[:billing_descriptor][:city] = options[:descriptor_city] if options[:descriptor_city]
        end
        post[:metadata] = {}
        post[:metadata][:udf5] = application_id || 'ActiveMerchant'
      end

      def add_payment_method(post, payment_method, options)
        post[:source] = {}
        post[:source][:type] = 'card'
        post[:source][:name] = payment_method.name
        post[:source][:number] = payment_method.number
        post[:source][:cvv] = payment_method.verification_value
        post[:source][:expiry_year] = format(payment_method.year, :four_digits)
        post[:source][:expiry_month] = format(payment_method.month, :two_digits)
        post[:source][:stored] = 'true' if options[:card_on_file] == true
      end

      def add_customer_data(post, options)
        post[:customer] = {}
        post[:customer][:email] = options[:email] || nil
        post[:payment_ip] = options[:ip] if options[:ip]
        address = options[:billing_address]
        if address && post[:source]
          post[:source][:billing_address] = {}
          post[:source][:billing_address][:address_line1] = address[:address1] unless address[:address1].blank?
          post[:source][:billing_address][:address_line2] = address[:address2] unless address[:address2].blank?
          post[:source][:billing_address][:city] = address[:city] unless address[:city].blank?
          post[:source][:billing_address][:state] = address[:state] unless address[:state].blank?
          post[:source][:billing_address][:country] = address[:country] unless address[:country].blank?
          post[:source][:billing_address][:zip] = address[:zip] unless address[:zip].blank?
        end
      end

      def add_transaction_data(post, options = {})
        post[:payment_type] = 'Regular' if options[:transaction_indicator] == 1
        post[:payment_type] = 'Recurring' if options[:transaction_indicator] == 2
        post[:previous_payment_id] = options[:previous_charge_id] if options[:previous_charge_id]
      end

      def add_3ds(post, options)
        if options[:three_d_secure]
          post[:'3ds'] = {}
          post[:'3ds'][:enabled] = true
          post[:'3ds'][:eci] = options[:three_d_secure][:eci] if options[:three_d_secure][:eci]
          post[:'3ds'][:cryptogram] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
          post[:'3ds'][:version] = options[:three_d_secure][:version] if options[:three_d_secure][:version]
          post[:'3ds'][:xid] = options[:three_d_secure][:ds_transaction_id] || options[:three_d_secure][:xid]
        end
      end

      def commit(action, post, authorization = nil)
        begin
          raw_response = ssl_post(url(post, action, authorization), post.to_json, headers)
          response = parse(raw_response)
          if action == :capture && response.key?('_links')
            response['id'] = response['_links']['payment']['href'].split('/')[-1]
          end
        rescue ResponseError => e
          raise unless e.response.code.to_s =~ /4\d\d/
          response = parse(e.response.body)
        end

        succeeded = success_from(response)

        response(action, succeeded, response)
      end

      def response(action, succeeded, response)
        successful_response = succeeded && action == :purchase || action == :authorize
        avs_result = successful_response ? avs_result(response) : nil
        cvv_result = successful_response ? cvv_result(response) : nil

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(succeeded, response),
          test: test?,
          avs_result: avs_result,
          cvv_result: cvv_result
        )
      end

      def headers
        {
          'Authorization' => @options[:secret_key],
          'Content-Type' => 'application/json;charset=UTF-8',
        }
      end

      def url(_post, action, authorization)
        if action == :authorize
          "#{base_url}/payments"
        elsif action == :capture
          "#{base_url}/payments/#{authorization}/captures"
        elsif action == :refund
          "#{base_url}/payments/#{authorization}/refunds"
        elsif action == :void
          "#{base_url}/payments/#{authorization}/voids"
        else
          "#{base_url}/payments/#{authorization}/#{action}"
        end
      end

      def base_url
        test? ? test_url : live_url
      end

      def avs_result(response)
        response['source'] && response['source']['avs_check'] ? AVSResult.new(code: response['source']['avs_check']) : nil
      end

      def cvv_result(response)
        response['source'] && response['source']['cvv_check'] ? CVVResult.new(response['source']['cvv_check']) : nil
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        {
          'message' => 'Invalid JSON response received from Checkout.com Unified Payments Gateway. Please contact Checkout.com if you continue to receive this message.',
          'raw_response' => scrub(body)
        }
      end

      def success_from(response)
        response['response_summary'] == 'Approved' || !response.key?('response_summary') && response.key?('action_id')
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        elsif response['error_type']
          response['error_type'] + ': ' + response['error_codes'].first
        else
          response['response_summary'] || response['response_code'] || 'Unable to read error message'
        end
      end

      STANDARD_ERROR_CODE_MAPPING = {
        '20014' => STANDARD_ERROR_CODE[:invalid_number],
        '20100' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '20054' => STANDARD_ERROR_CODE[:expired_card],
        '40104' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '40108' => STANDARD_ERROR_CODE[:incorrect_zip],
        '40111' => STANDARD_ERROR_CODE[:incorrect_address],
        '20005' => STANDARD_ERROR_CODE[:card_declined],
        '20088' => STANDARD_ERROR_CODE[:processing_error],
        '20001' => STANDARD_ERROR_CODE[:call_issuer],
        '30004' => STANDARD_ERROR_CODE[:pickup_card]
      }

      def authorization_from(raw)
        raw['id']
      end

      def error_code_from(succeeded, response)
        return if succeeded
        if response['error_type'] && response['error_codes']
          "#{response['error_type']}: #{response['error_codes'].join(', ')}"
        elsif response['error_type']
          response['error_type']
        else
          STANDARD_ERROR_CODE_MAPPING[response['response_code']]
        end
      end
    end
  end
end
