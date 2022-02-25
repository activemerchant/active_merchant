require 'json'

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

      self.homepage_url = 'http://www.example.net/'
      self.display_name = 'New Gateway'

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

      # Necesita revision, puede darse el caso de que no necesitamos parametrizar todo
      # debido a que puede enviar los datos armado
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
        add_if_has_key(forward_route, options, :trace_id)
        forward_route[:psp_extra_fields] = options[:psp_extra_fields] || {}
        post[:forward_route] = forward_route
      end

      def add_forward_payload(post, money, payment, options)
        forward_payload = {}
        add_user(forward_payload, options[:user])
        add_order(forward_payload, money, options[:order])
        add_payment_method(forward_payload, payment, options[:payment_method])
        forward_payload[:authentication] = {} unless forward_payload.key?(:authentication)
        add_three_ds_fields(forward_payload[:authentication], options[:three_ds_fields]) if options[:three_ds_fields]
        add_sub_merchant(forward_payload, options[:sub_merchant])
        forward_payload[:acquire_extra_options] = options[:acquire_extra_options] || {}
        post[:forward_payload] = forward_payload
      end

      def add_sub_merchant(post, sub_merchant_options)
        sub_merchant = {}

        add_if_has_key(sub_merchant, sub_merchant_options, :merchant_id, :extra_params, :mcc, :name, :address,
          :postal_code, :url, :phone_number)

        post[:sub_merchant] = sub_merchant
      end

      def add_payment_method(post, payment, payment_method_options)
        payment_method = {}

        add_card(payment_method, payment, payment_method_options[:card])

        post[:payment_method] = payment_method
      end

      def add_three_ds_fields(post, three_ds_options)
        three_ds = {}
        add_if_has_key(three_ds, three_ds_options, :version, :eci, :cavv, :ds_transaction_id, :acs_transaction_id, :xid,
          :enrolled, :cavv_algorithm, :directory_response_status, :authentication_response_status, :three_ds_server_trans_id)

        post[:three_ds_fields] = three_ds
      end

      def add_card(post, card, card_options)
        card_hash = {}
        card_hash[:number] = card.number
        card_hash[:exp_month] = card.month
        card_hash[:exp_year] = card.year
        card_hash[:security_code] = card.verification_value
        card_hash[:type] = card.brand
        card_hash[:holder_first_name] = card.first_name
        card_hash[:holder_last_name] = card.last_name
        add_address('billing_address', card_hash, card_options[:billing_address])

        post[:card] = card_hash
      end

      def add_user(post, user_options)
        user = {}

        add_if_has_key(user, user_options, :id, :email)

        post[:user] = user
      end

      def add_stored_credential(post, options)
        return unless options[:stored_credential]

        check_initiator = %w[merchant credit_card_holder].any? { |item| item == options[:stored_credential][:initiator] }
        check_reason_type = %w[recurring installment unscheduled].any? { |item| item == options[:stored_credential][:reason_type] }
        post[:forward_payload][:authentication] = {} unless post[:forward_payload].key?(:authentication)
        post[:forward_payload][:authentication][:stored_credential] = options[:stored_credential] if check_initiator && check_reason_type
      end

      def add_order(post, money, order_options)
        order = {}

        add_if_has_key(order, order_options, :id, :description, :installments, :datetime_local_transaction)
        add_amount(order, money, order_options[:amount])
        add_address('shipping_address', order, order_options[:shipping_address])

        post[:order] = order
      end

      def add_amount(post, money, amount_options)
        amount_obj = {}
        amount_obj[:total_amount] = amount(money).to_f
        amount_obj[:currency] = (amount_options[:currency] || currency(money))

        add_if_has_key(amount_obj, amount_options, :vat)

        post[:amount] = amount_obj
      end

      def add_address(tag, post, address_options)
        address = {}

        add_if_has_key(address, address_options, :name, :company, :address1, :address2, :city, :state, :country, :zip, :phone)

        post[tag] = address
      end

      def add_if_has_key(add, from, *params)
        if from
          params.each do |param|
            add[param] = from[param] if from.has_key?(param)
          end
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, url_params = {})
        response = custom_handle_response(raw_ssl_request(:post, url(action, url_params), post_data(parameters), authorized_headers()))
        response_body = JSON.parse response.body

        Response.new(
          success_from(response.code.to_i),
          message_from(response_body),
          response_body,
          authorization: authorization_from(response_body),
          avs_result: AVSResult.new(code: avs_code_from(response_body)),
          cvv_result: CVVResult.new(cvv_code_from(response_body)),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def custom_handle_response(response)
        case response.code.to_i
        when 200...501
          response
        else
          raise ResponseError.new(response)
        end
      end

      def avs_code_from(response)
        response['avs_result']
      end

      def cvv_code_from(response)
        response['cvv_result']
      end

      def success_from(status_code)
        status_code == 200
      end

      def message_from(response)
        response[:message] || response['message']
      end

      def url(action, url_params)
        if url_params[:token_acquirer]
          "#{(test? ? test_url : live_url)}/#{url_params[:token_acquirer]}/#{action}"
        else
          "#{(test? ? test_url : live_url)}/#{action}"
        end
      end

      def post_data(data = {})
        data.to_json
      end

      def authorization_from(response)
        response['simetrik_authorization_id']
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response.code] unless success_from(response)
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
