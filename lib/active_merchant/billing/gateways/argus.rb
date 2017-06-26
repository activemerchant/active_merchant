module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information visit {Argus Payments}[http://www.arguspayments.com/pubsite/public/?/support/document]
    #
    # Written by Piers Chambers (Varyonic.com)
    class ArgusGateway < Gateway
      include Empty

      self.test_url = 'https://svc.arguspayments.com/payment/pmt_service.cfm'
      self.live_url = 'https://svc.arguspayments.com/payment/pmt_service.cfm'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners, :jcb]

      self.homepage_url = 'http://http://www.arguspayments.com/'
      self.display_name = 'Argus Payments'

      STANDARD_ERROR_CODE_MAPPING = {
        '555' => STANDARD_ERROR_CODE[:call_issuer],
        '600' => STANDARD_ERROR_CODE[:card_declined],
        '620' => STANDARD_ERROR_CODE[:invalid_cvc],
        '621' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '623' => STANDARD_ERROR_CODE[:incorrect_address],
        '624' => STANDARD_ERROR_CODE[:expired_card],
        '630' => STANDARD_ERROR_CODE[:invalid_number],
        '610' => STANDARD_ERROR_CODE[:pickup_card],
      }

      def initialize(options={})
        requires!(options, :site_id, :req_username, :req_password)
        super
      end

      def purchase(money, payment, options={})
        post = PostData.new
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('CCAUTHCAP', post)
      end

      def authorize(money, payment, options={})
        post = PostData.new
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('CCAUTHORIZE', post)
      end

      def capture(money, authorization, options={})
        post = PostData.new
        post[:li_value_1] = amount(money)
        post[:request_ref_po_id] = authorization
        commit('CCCAPTURE', post)
      end

      def refund(money, authorization, options={})
        post = PostData.new
        post[:li_value_1] = amount(money)
        post[:request_ref_po_id] = authorization
        commit('CCCREDIT', post)
      end

      def void(authorization, options={})
        post = PostData.new
        post[:request_ref_po_id] = authorization
        commit('CCREVERSE', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.gsub(%r((&?pmt_numb=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?pmt_key=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?req_password=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:cust_email] = options[:email] unless empty?(options[:email])
        post[:cust_fname] = options[:first_name]
        post[:cust_lname] = options[:last_name]
        # TODO: first_name, last_name = split_names(address[:name])
        add_shipping_address(post, options)
      end

      def add_address(post, creditcard, options)
        address = options[:billing_address] || options[:address] || {}
        post[:bill_addr] = truncate(address[:address1], 60)
        post[:bill_addr_city] = truncate(address[:city], 40)
        post[:bill_addr_country] = truncate(address[:country], 60)
        post[:bill_addr_state] = empty?(address[:state]) ? 'n/a' : truncate(address[:state], 40)
        post[:bill_addr_zip] = truncate((address[:zip] || options[:zip]), 20)
      end

      def add_shipping_address(post, options)
        address = options[:shipping_address] || options[:address]
        return unless address

        post[:ship_addr] = truncate(address[:address1], 60)
        post[:ship_addr_city] = truncate(address[:city], 40)
        post[:ship_addr_country] = truncate(address[:country], 60)
        post[:ship_addr_state] = empty?(address[:state]) ? 'n/a' : truncate(address[:state], 40)
        post[:ship_addr_zip] = truncate((address[:zip] || options[:zip]), 20)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:li_prod_id_1] = options[:li_prod_id_1] # 'Dynamic Amount Product ID'
        post[:li_value_1] = amount(money)
      end

      def add_payment(post, payment)
        post[:pmt_expiry] = sprintf('%02d/%04d', payment.month, payment.year)
        post[:pmt_key] = payment.verification_value
        post[:pmt_numb] = truncate(payment.number, 16)
        post[:request_currency] = 'USD'
        post[:merch_acct_id] = @options[:merch_acct_id]
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        json_error(body)
      end

      def json_error(body)
        {
          'error' => {
            'message' => "Invalid JSON response body: #{body})",
            'raw_response' => scrub(body)
          }
        }
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['AVS_RESPONSE']),
          cvv_result: CVVResult.new(response['CVV_RESPONSE']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['TRANS_STATUS_NAME'] == 'APPROVED'
      end

      def message_from(response)
        error = [
          format_error_fields(response, 'API_RESPONSE', 'API_ADVICE'), # e.g. missing/invalid credentials or data
          format_error_fields(response, 'SERVICE_RESPONSE', 'SERVICE_ADVICE'), # e.g. expired card
          (response['REF_FIELD'] unless empty?(response['REF_FIELD']))
        ].compact.join(': ')

        empty?(error) ? response['TRANS_STATUS_NAME'] : error
      end

      def format_error_fields(response, code, message)
        "(#{response[code]}) #{response[message]}" unless ['', '0'].include? response[code].to_s
      end

      def authorization_from(response)
        response['PO_ID'].to_s
      end

      def post_data(action, parameters = {})
        parameters[:request_action] = action
        parameters[:request_api_version] = 3.6,
                                           parameters[:request_response_format] = 'JSON'
        parameters.merge!(credentials).to_post_data
      end

      def credentials
        {
          site_id: @options[:site_id],
          req_username: @options[:req_username],
          req_password: @options[:req_password]
        }
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response['SERVICE_RESPONSE'].to_s]
        end
      end
    end
  end
end
