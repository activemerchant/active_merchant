module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayComGateway < Gateway
      self.test_url = 'https://api.dev.pay.com/payments'
      self.live_url = 'https://api.dev.pay.com/payments'

      self.supported_countries = ['US', 'GB', 'CY']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master]

      self.homepage_url = 'http://www.pay.com/'
      self.display_name = 'Pay.com'

      AVS_CODE_MAPPER = {
        'line1: pass, zip: pass' => 'Y',
        'line1: pass, zip: fail' => 'A',
        'line1: pass, zip: unchecked' => 'B',
        'line1: fail, zip: pass' => 'Z',
        'line1: fail, zip: fail' => 'N',
        'line1: unchecked, zip: pass' => 'P',
        'line1: unchecked, zip: unchecked' => 'I',
        'line1: unavailable, zip: unavailable' => 'R',
        'line1: unavailable, zip: pass' => 'P',
        'line1: unavailable, zip: fail' => 'I',
        'line1: unavailable, zip: unchecked' => 'I',
        'line1: pass, zip: unavailable' => 'B',
        'line1: fail, zip: unavailable' => 'I',
        'line1: unchecked, zip: unavailable' => 'I',
      }

      CVC_CODE_MAPPER = {
        'pass' => 'M',
        'fail' => 'N',
        'unchecked' => 'P',
        'unavailable' => 'P',
      }

      STANDARD_ERROR_CODE_MAPPING = {
        1 => STANDARD_ERROR_CODE[:call_issuer],
        2 => STANDARD_ERROR_CODE[:call_issuer],
        3 => STANDARD_ERROR_CODE[:config_error],
        4 => STANDARD_ERROR_CODE[:pickup_card],
        5 => STANDARD_ERROR_CODE[:card_declined],
        7 => STANDARD_ERROR_CODE[:pickup_card],
        12 => STANDARD_ERROR_CODE[:processing_error],
        14 => STANDARD_ERROR_CODE[:invalid_number],
        28 => STANDARD_ERROR_CODE[:processing_error],
        38 => STANDARD_ERROR_CODE[:incorrect_pin],
        39 => STANDARD_ERROR_CODE[:invalid_number],
        43 => STANDARD_ERROR_CODE[:pickup_card],
        45 => STANDARD_ERROR_CODE[:card_declined],
        46 => STANDARD_ERROR_CODE[:invalid_number],
        47 => STANDARD_ERROR_CODE[:card_declined],
        48 => STANDARD_ERROR_CODE[:card_declined],
        49 => STANDARD_ERROR_CODE[:invalid_expiry_date],
        51 => STANDARD_ERROR_CODE[:card_declined],
        53 => STANDARD_ERROR_CODE[:card_declined],
        54 => STANDARD_ERROR_CODE[:expired_card],
        55 => STANDARD_ERROR_CODE[:incorrect_pin],
        56 => STANDARD_ERROR_CODE[:card_declined],
        57 => STANDARD_ERROR_CODE[:card_declined],
        76 => STANDARD_ERROR_CODE[:call_issuer],
        91 => STANDARD_ERROR_CODE[:call_issuer],
        96 => STANDARD_ERROR_CODE[:processing_error],
        97 => STANDARD_ERROR_CODE[:processing_error],
        'default' => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options = {})
        requires!(options, :api_key)
        @api_key = options[:api_key]
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options = {})
        if authorization == '' || authorization == nil
          return response_for_missing_authorization('capture')
        end

        post = {
          :authorization => authorization,
          :amount => (amount(money) if money != nil)
        }.delete_if{ |k,v| v.nil? }

        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        if authorization == '' || authorization == nil
          return response_for_missing_authorization('refund')
        end

        post = {
          :authorization => authorization,
          :amount => (amount(money) if money != nil)
        }.delete_if{ |k,v| v.nil? }

        commit('refund', post)
      end

      def void(authorization, options = {})
        if authorization == '' || authorization == nil
          return response_for_missing_authorization('void')
        end

        commit('void', { authorization: authorization })
      end

      private
      def add_customer_data(post, options)
        consumer = if options[:consumer_id] != nil
          { id: options[:consumer_id] }
        else
          options[:consumer_details]
        end

        post['consumer'] = consumer
      end

      def add_address(post, creditcard, options)
        post['billing'] = options[:billing_address]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        payment_method = if payment.is_a?(String)
          {
            type: 'card_token',
            card_token: payment,
          }
        else
          {
            type: 'card',
            card: {
              number: payment.number,
              expiry_year: "#{payment.year}",
              expiry_month: "#{payment.month}",
              name: "#{payment.first_name} #{payment.last_name}",
              cvv: payment.verification_value,
            }
          }
        end
        post['source'] = {
          type: 'payment_method',
          payment_method: payment_method
        }
      end

      def parse(body)
        return {} if body.blank?

        JSON.parse(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)

        response = parse(ssl_post(build_url(action, url, parameters), post_data(action, parameters), request_headers()))
        success = success_from(response)

        avs_result = avs_result_from(response, action)
        cvv_result = cvv_result_from(response, action)

        Response.new(
          success,
          message_from(response, success),
          response,
          authorization: authorization_from(response),
          avs_result: avs_result,
          cvv_result: cvv_result,
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def response_for_missing_authorization(action)
        Response.new(
          false,
          "Authorization id must be provided for #{action}",
          {},
          test: test?,
        )
      end

      def avs_result_from(response, action)
        if action == 'sale' || action == 'authonly'
          {code: AVS_CODE_MAPPER[String.new("line1: #{response['payment_method']['card']['address_line1_check'].downcase}, zip: #{response['payment_method']['card']['address_postal_code_check']}").downcase] }
        end
      end

      def cvv_result_from(response, action)
        if action == 'sale' || action == 'authonly'
          CVC_CODE_MAPPER[String.new(response['payment_method']['card']['cvc_check'].downcase)]
        end
      end

      def success_from(response)
        !response.key?('error') && response['status'] != 'DECLINED'
      end

      def message_from(response, success)
        if success
          'Transaction approved'
        else
          if response['status'] == 'DECLINED'
            response.fetch('result', { 'status_message' => 'No declined details' })['status_message']
          else
            response.fetch('error', { 'message' => 'No error details' })['message']
          end
        end
      end

      def authorization_from(response)
        response['id']
      end

      def generate_json_with_amount(amount)
        JSON.generate({ :amount => (amount if amount != nil) }.delete_if{ |k,v| v.nil? })
      end

      def post_data(action, parameters = {})
        case action
          when 'authonly'
            parameters['capture_method'] = 'manual'
          when 'sale'
            parameters['capture_method'] = 'immediately'
          when 'capture'
            return generate_json_with_amount(parameters[:amount])
          when 'refund'
            return generate_json_with_amount(parameters[:amount])
          when 'void'
            return generate_json_with_amount(parameters[:amount])
        end

        JSON.generate(parameters)
      end

      def build_url(action, url, params = {})
        case action
          when 'capture'
            "#{url}/#{params[:authorization]}/capture"
          when 'refund'
            "#{url}/#{params[:authorization]}/refund"
          when 'void'
            "#{url}/#{params[:authorization]}/cancel"
          else
            url
        end
      end

      def request_headers()
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@api_key}"
        }

        headers
      end

      def error_code_from(response)
        success = success_from(response)
        unless success
          status_code = response.fetch('result', { 'status_code' => 'default' })['status_code']

          STANDARD_ERROR_CODE_MAPPING[status_code]
        end
      end
    end
  end
end
