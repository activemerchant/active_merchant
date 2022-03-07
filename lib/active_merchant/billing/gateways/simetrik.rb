module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SimetrikGateway < Gateway
      self.test_url = 'https://payments.sta.simetrik.com/v1'
      self.live_url = 'https://payments.simetrik.com/v1'

      class_attribute :test_auth_url, :live_auth_url
      self.test_auth_url = 'https://tenant-payments-dev.us.auth0.com/oauth/token'
      self.live_auth_url = 'https://tenant-payments-prod.us.auth0.com/oauth/token'

      self.supported_countries = %w(PE AR)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.simetrik.com'
      self.display_name = 'Simetrik'

      STANDARD_ERROR_CODE_MAPPING = {
        'R101' => STANDARD_ERROR_CODE[:incorrect_number],
        'R102' => STANDARD_ERROR_CODE[:invalid_number],
        'R103' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'R104' => STANDARD_ERROR_CODE[:invalid_cvc],
        'R105' => STANDARD_ERROR_CODE[:expired_card],
        'R106' => STANDARD_ERROR_CODE[:incorrect_cvc],
        'R107' => STANDARD_ERROR_CODE[:incorrect_pin],
        'R201' => STANDARD_ERROR_CODE[:incorrect_zip],
        'R202' => STANDARD_ERROR_CODE[:incorrect_address],
        'R301' => STANDARD_ERROR_CODE[:card_declined],
        'R302' => STANDARD_ERROR_CODE[:processing_error],
        'R303' => STANDARD_ERROR_CODE[:call_issuer],
        'R304' => STANDARD_ERROR_CODE[:pick_up_card],
        'R305' => STANDARD_ERROR_CODE[:processing_error],
        'R306' => STANDARD_ERROR_CODE[:processing_error],
        'R307' => STANDARD_ERROR_CODE[:processing_error],
        'R401' => STANDARD_ERROR_CODE[:config_error],
        'R402' => STANDARD_ERROR_CODE[:test_mode_live_card],
        'R403' => STANDARD_ERROR_CODE[:unsupported_feature]

      }

      def initialize(options = {})
        requires!(options, :client_id, :client_secret, :audience)
        super
        @access_token = {}
        sign_access_token()
      end

      def authorize(money, payment, options = {})
        requires!(options, :token_acquirer)

        post = {}
        add_forward_route(post, options)
        add_forward_payload(post, money, payment, options)
        add_stored_credential(post, options)

        commit('authorize', post, { token_acquirer: options[:token_acquirer] })
      end

      def capture(money, authorization, options = {})
        requires!(options, :token_acquirer)
        post = {
          forward_payload: {
            amount: {
              total_amount: amount(money).to_f,
              vat: options[:vat],
              currency: (options[:currency] || currency(money))
            },
            transaction: {
              id: authorization
            },
            acquire_extra_options: options[:acquire_extra_options] || {}
          }
        }

        add_forward_route(post, options)
        commit('capture', post, { token_acquirer: options[:token_acquirer] })
      end

      def refund(money, authorization, options = {})
        requires!(options, :token_acquirer)
        post = {
          forward_payload: {
            amount: {
              total_amount: amount(money).to_f,
              currency: (options[:currency] || currency(money))
            },
            transaction: {
              id: authorization,
              comment: options[:comment]
            },
            acquire_extra_options: options[:acquire_extra_options] || {}
          }
        }

        add_forward_route(post, options)
        commit('refund', post, { token_acquirer: options[:token_acquirer] })
      end

      def void(authorization, options = {})
        requires!(options, :token_acquirer)
        post = {
          forward_payload: {
            transaction: {
              id: authorization
            },
            acquire_extra_options: options[:acquire_extra_options] || {}
          }
        }
        add_forward_route(post, options)
        commit('void', post, { token_acquirer: options[:token_acquirer] })
      end

      def purchase(money, payment, options = {})
        requires!(options, :token_acquirer)

        post = {}
        add_forward_route(post, options)
        add_forward_payload(post, money, payment, options)

        add_stored_credential(post, options)
        commit('charge', post, { token_acquirer: options[:token_acquirer] })
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((\"number\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"security_code\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"exp_month\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"exp_year\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"holder_first_name\\\":\\\")"\w+"), '\1[FILTERED]').
          gsub(%r((\"holder_last_name\\\":\\\")"\w+"), '\1[FILTERED]')
      end

      private

      def add_forward_route(post, options)
        forward_route = {}
        forward_route[:trace_id] = options[:trace_id] if options[:trace_id]

        forward_route[:psp_extra_fields] = options[:psp_extra_fields] || {}
        post[:forward_route] = forward_route
      end

      def add_forward_payload(post, money, payment, options)
        forward_payload = {}
        add_user(forward_payload, options[:user]) if options[:user]
        add_order(forward_payload, money, options[:order]) if options[:order] || money
        add_payment_method(forward_payload, payment, options[:payment_method]) if options[:payment_method] || payment
        add_three_ds_fields(forward_payload[:authentication] = {}, options[:three_ds_fields]) if options[:three_ds_fields]
        add_sub_merchant(forward_payload, options[:sub_merchant])
        forward_payload[:acquire_extra_options] = options[:acquire_extra_options] || {}
        post[:forward_payload] = forward_payload
      end

      def add_sub_merchant(post, sub_merchant_options)
        sub_merchant = {}
        sub_merchant[:merchant_id] = sub_merchant_options[:merchant_id]
        sub_merchant[:extra_params] = sub_merchant_options[:extra_params]
        sub_merchant[:mcc] =  sub_merchant_options[:mcc]
        sub_merchant[:name] = sub_merchant_options[:name]
        sub_merchant[:address] = sub_merchant_options[:address]
        sub_merchant[:postal_code] = sub_merchant_options[:postal_code]
        sub_merchant[:url] = sub_merchant_options[:url]
        sub_merchant[:phone_number] = sub_merchant_options[:phone_number]

        post[:sub_merchant] = sub_merchant
      end

      def add_payment_method(post, payment, payment_method_options)
        payment_method = {}
        opts = nil
        opts = payment_method_options[:card] if payment_method_options
        add_card(payment_method, payment, opts)

        post[:payment_method] = payment_method
      end

      def add_three_ds_fields(post, three_ds_options)
        three_ds = {}
        three_ds[:version] = three_ds_options[:version] if three_ds_options[:version]
        three_ds[:eci] = three_ds_options[:eci] if three_ds_options[:eci]
        three_ds[:cavv] = three_ds_options[:cavv] if three_ds_options[:cavv]
        three_ds[:ds_transaction_id] = three_ds_options[:ds_transaction_id] if three_ds_options[:ds_transaction_id]
        three_ds[:acs_transaction_id] = three_ds_options[:acs_transaction_id] if three_ds_options[:acs_transaction_id]
        three_ds[:xid] = three_ds_options[:xid] if three_ds_options[:xid]
        three_ds[:enrolled] = three_ds_options[:enrolled] if three_ds_options[:enrolled]
        three_ds[:cavv_algorithm] = three_ds_options[:cavv_algorithm] if three_ds_options[:cavv_algorithm]
        three_ds[:directory_response_status] = three_ds_options[:directory_response_status] if three_ds_options[:directory_response_status]
        three_ds[:authentication_response_status] = three_ds_options[:authentication_response_status] if three_ds_options[:authentication_response_status]
        three_ds[:three_ds_server_trans_id] = three_ds_options[:three_ds_server_trans_id] if three_ds_options[:three_ds_server_trans_id]

        post[:three_ds_fields] = three_ds
      end

      def add_card(post, card, card_options = {})
        card_hash = {}
        card_hash[:number] = card.number
        card_hash[:exp_month] = card.month
        card_hash[:exp_year] = card.year
        card_hash[:security_code] = card.verification_value
        card_hash[:type] = card.brand
        card_hash[:holder_first_name] = card.first_name
        card_hash[:holder_last_name] = card.last_name
        add_address('billing_address', card_hash, card_options[:billing_address]) if card_options
        post[:card] = card_hash
      end

      def add_user(post, user_options)
        user = {}
        user[:id] = user_options[:id] if user_options[:id]
        user[:email] = user_options[:email] if user_options[:email]

        post[:user] = user
      end

      def add_stored_credential(post, options)
        return unless options[:stored_credential]

        check_initiator = %w[merchant cardholder].any? { |item| item == options[:stored_credential][:initiator] }
        check_reason_type = %w[recurring installment unscheduled].any? { |item| item == options[:stored_credential][:reason_type] }
        post[:forward_payload][:authentication] = {} unless post[:forward_payload].key?(:authentication)
        post[:forward_payload][:authentication][:stored_credential] = options[:stored_credential] if check_initiator && check_reason_type
      end

      def add_order(post, money, order_options)
        order = {}
        order[:id] = order_options[:id] if order_options[:id]
        order[:description] = order_options[:description] if order_options[:description]
        order[:installments] = order_options[:installments] if order_options[:installments]
        order[:datetime_local_transaction] = order_options[:datetime_local_transaction] if order_options[:datetime_local_transaction]

        add_amount(order, money, order_options[:amount])
        add_address('shipping_address', order, order_options[:shipping_address]) if order_options[:shipping_address]

        post[:order] = order
      end

      def add_amount(post, money, amount_options)
        amount_obj = {}
        amount_obj[:total_amount] = amount(money).to_f
        amount_obj[:currency] = (amount_options[:currency] || currency(money))
        amount_obj[:vat] = amount_options[:vat] if amount_options[:vat]

        post[:amount] = amount_obj
      end

      def add_address(tag, post, address_options)
        address = {}
        address[:name] = address_options[:name] if address_options[:name]
        address[:company] = address_options[:company] if address_options[:company]
        address[:address1] = address_options[:address1] if address_options[:address1]
        address[:address2] = address_options[:address2] if address_options[:address2]
        address[:city] = address_options[:city] if address_options[:city]
        address[:state] = address_options[:state] if address_options[:state]
        address[:country] = address_options[:country] if address_options[:country]
        address[:zip] = address_options[:zip] if address_options[:zip]
        address[:phone] = address_options[:phone] if address_options[:phone]

        post[tag] = address
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, url_params = {})
        begin
          response = JSON.parse ssl_post(url(action, url_params), post_data(parameters), authorized_headers())
        rescue ResponseError => exception
          case exception.response.code.to_i
          when 400...499
            response = JSON.parse exception.response.body
          else
            raise exception
          end
        end

        Response.new(
          success_from(response['code']),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: avs_code_from(response)),
          cvv_result: CVVResult.new(cvv_code_from(response)),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def avs_code_from(response)
        response['avs_result']
      end

      def cvv_code_from(response)
        response['cvv_result']
      end

      def success_from(code)
        code == 'S001'
      end

      def message_from(response)
        response['message']
      end

      def url(action, url_params)
        "#{(test? ? test_url : live_url)}/#{url_params[:token_acquirer]}/#{action}"
      end

      def post_data(data = {})
        data.to_json
      end

      def authorization_from(response)
        response['simetrik_authorization_id']
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['code']] unless success_from(response['code'])
      end

      def authorized_headers
        {
          'content-Type' => 'application/json',
          'Authorization' => "Bearer #{sign_access_token()}"
        }
      end

      def sign_access_token
        fetch_access_token() if Time.new.to_i > (@access_token[:expires_at] || 0) + 10
        @access_token[:access_token]
      end

      def auth_url
        (test? ? test_auth_url : live_auth_url)
      end

      def fetch_access_token
        login_info = {}
        login_info[:client_id] = @options[:client_id]
        login_info[:client_secret] = @options[:client_secret]
        login_info[:audience] = @options[:audience]
        login_info[:grant_type] = 'client_credentials'
        response = parse(ssl_post(auth_url(), login_info.to_json, {
          'content-Type' => 'application/json'
        }))

        @access_token[:access_token] = response['access_token']
        @access_token[:expires_at] = Time.new.to_i + response['expires_in']
      end
    end
  end
end
