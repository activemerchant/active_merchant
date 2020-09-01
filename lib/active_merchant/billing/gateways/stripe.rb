require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This gateway uses an older version of the Stripe API.
    # To utilize the updated {Payment Intents API}[https://stripe.com/docs/api/payment_intents], integrate with the StripePaymentIntents gateway
    class StripeGateway < Gateway
      self.live_url = 'https://api.stripe.com/v1/'

      AVS_CODE_TRANSLATOR = {
        'line1: pass, zip: pass' => 'Y',
        'line1: pass, zip: fail' => 'A',
        'line1: pass, zip: unchecked' => 'B',
        'line1: fail, zip: pass' => 'Z',
        'line1: fail, zip: fail' => 'N',
        'line1: unchecked, zip: pass' => 'P',
        'line1: unchecked, zip: unchecked' => 'I'
      }

      CVC_CODE_TRANSLATOR = {
        'pass' => 'M',
        'fail' => 'N',
        'unchecked' => 'P'
      }

      DEFAULT_API_VERSION = '2015-04-07'

      self.supported_countries = %w(AT AU BE BG BR CA CH CY CZ DE DK EE ES FI FR GB GR HK IE IT JP LT LU LV MT MX NL NO NZ PL PT RO SE SG SI SK US)
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express discover jcb diners_club maestro]
      self.currencies_without_fractions = %w(BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF VND VUV XAF XOF XPF UGX)

      self.homepage_url = 'https://stripe.com/'
      self.display_name = 'Stripe'

      STANDARD_ERROR_CODE_MAPPING = {
        'incorrect_number' => STANDARD_ERROR_CODE[:incorrect_number],
        'invalid_number' => STANDARD_ERROR_CODE[:invalid_number],
        'invalid_expiry_month' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_expiry_year' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_cvc' => STANDARD_ERROR_CODE[:invalid_cvc],
        'expired_card' => STANDARD_ERROR_CODE[:expired_card],
        'incorrect_cvc' => STANDARD_ERROR_CODE[:incorrect_cvc],
        'incorrect_zip' => STANDARD_ERROR_CODE[:incorrect_zip],
        'card_declined' => STANDARD_ERROR_CODE[:card_declined],
        'call_issuer' => STANDARD_ERROR_CODE[:call_issuer],
        'processing_error' => STANDARD_ERROR_CODE[:processing_error],
        'incorrect_pin' => STANDARD_ERROR_CODE[:incorrect_pin],
        'test_mode_live_card' => STANDARD_ERROR_CODE[:test_mode_live_card],
        'pickup_card' => STANDARD_ERROR_CODE[:pickup_card]
      }

      BANK_ACCOUNT_HOLDER_TYPE_MAPPING = {
        'personal' => 'individual',
        'business' => 'company'
      }

      MINIMUM_AUTHORIZE_AMOUNTS = {
        'USD' => 100,
        'CAD' => 100,
        'GBP' => 60,
        'EUR' => 100,
        'DKK' => 500,
        'NOK' => 600,
        'SEK' => 600,
        'CHF' => 100,
        'AUD' => 100,
        'JPY' => 100,
        'MXN' => 2000,
        'SGD' => 100,
        'HKD' => 800
      }

      def initialize(options = {})
        requires!(options, :login)
        @api_key = options[:login]
        @fee_refund_api_key = options[:fee_refund_login]
        super
      end

      def authorize(money, payment, options = {})
        if ach?(payment)
          direct_bank_error = 'Direct bank account transactions are not supported for authorize.'
          return Response.new(false, direct_bank_error)
        end

        MultiResponse.run do |r|
          if payment.is_a?(ApplePayPaymentToken)
            r.process { tokenize_apple_pay_token(payment) }
            payment = StripePaymentToken.new(r.params['token']) if r.success?
          end
          r.process do
            post = create_post_for_auth_or_purchase(money, payment, options)
            add_application_fee(post, options) if emv_payment?(payment)
            post[:capture] = 'false'
            commit(:post, 'charges', post, options)
          end
        end.responses.last
      end

      # To create a charge on a card or a token, call
      #
      #   purchase(money, card_hash_or_token, { ... })
      #
      # To create a charge on a customer, call
      #
      #   purchase(money, nil, { :customer => id, ... })
      def purchase(money, payment, options = {})
        if ach?(payment)
          direct_bank_error = 'Direct bank account transactions are not supported. Bank accounts must be stored and verified before use.'
          return Response.new(false, direct_bank_error)
        end

        MultiResponse.run do |r|
          if payment.is_a?(ApplePayPaymentToken)
            r.process { tokenize_apple_pay_token(payment) }
            payment = StripePaymentToken.new(r.params['token']) if r.success?
          end
          r.process do
            post = create_post_for_auth_or_purchase(money, payment, options)
            post[:card][:processing_method] = 'quick_chip' if quickchip_payment?(payment)
            commit(:post, 'charges', post, options)
          end
        end.responses.last
      end

      def capture(money, authorization, options = {})
        post = {}

        if emv_tc_response = options.delete(:icc_data)
          # update the charge with emv data if card present
          update = {}
          update[:card] = { emv_approval_data: emv_tc_response }
          commit(:post, "charges/#{CGI.escape(authorization)}", update, options)
        else
          add_application_fee(post, options)
          add_amount(post, money, options)
          add_exchange_rate(post, options)
        end

        commit(:post, "charges/#{CGI.escape(authorization)}/capture", post, options)
      end

      def void(identification, options = {})
        post = {}
        post[:metadata] = options[:metadata] if options[:metadata]
        post[:reason] = options[:reason] if options[:reason]
        post[:expand] = [:charge]
        commit(:post, "charges/#{CGI.escape(identification)}/refunds", post, options)
      end

      def refund(money, identification, options = {})
        post = {}
        add_amount(post, money, options)
        post[:refund_application_fee] = true if options[:refund_application_fee]
        post[:reverse_transfer] = options[:reverse_transfer] if options[:reverse_transfer]
        post[:metadata] = options[:metadata] if options[:metadata]
        post[:reason] = options[:reason] if options[:reason]
        post[:expand] = [:charge]

        response = commit(:post, "charges/#{CGI.escape(identification)}/refunds", post, options)

        if response.success? && options[:refund_fee_amount] && options[:refund_fee_amount].to_s != '0'
          charge = api_request(:get, "charges/#{CGI.escape(identification)}", nil, options)

          if application_fee = charge['application_fee']
            fee_refund_options = {
              currency: options[:currency], # currency isn't used by Stripe here, but we need it for #add_amount
              key: @fee_refund_api_key
            }
            refund_application_fee(options[:refund_fee_amount].to_i, application_fee, fee_refund_options)
          end
        end

        response
      end

      def verify(payment, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(auth_minimum_amount(options), payment, options) }
          options[:idempotency_key] = nil
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def refund_application_fee(money, identification, options = {})
        post = {}
        add_amount(post, money, options)
        commit(:post, "application_fees/#{CGI.escape(identification)}/refunds", post, options)
      end

      # Note: creating a new credit card will not change the customer's existing default credit card (use :set_default => true)
      def store(payment, options = {})
        params = {}
        post = {}

        if payment.is_a?(ApplePayPaymentToken)
          token_exchange_response = tokenize_apple_pay_token(payment)
          params = { card: token_exchange_response.params['token']['id'] } if token_exchange_response.success?
        elsif payment.is_a?(StripePaymentToken)
          add_payment_token(params, payment, options)
        elsif payment.is_a?(Check)
          bank_token_response = tokenize_bank_account(payment)
          return bank_token_response unless bank_token_response.success?

          params = { source: bank_token_response.params['token']['id'] }
        else
          add_creditcard(params, payment, options)
        end

        post[:validate] = options[:validate] unless options[:validate].nil?
        post[:description] = options[:description] if options[:description]
        post[:email] = options[:email] if options[:email]

        if options[:account]
          add_external_account(post, params, payment)
          commit(:post, "accounts/#{CGI.escape(options[:account])}/external_accounts", post, options)
        elsif options[:customer]
          MultiResponse.run(:first) do |r|
            # The /cards endpoint does not update other customer parameters.
            r.process { commit(:post, "customers/#{CGI.escape(options[:customer])}/cards", params, options) }

            post[:default_card] = r.params['id'] if options[:set_default] and r.success? and !r.params['id'].blank?

            r.process { update_customer(options[:customer], post) } if post.count > 0
          end
        else
          commit(:post, 'customers', post.merge(params), options)
        end
      end

      def update(customer_id, card_id, options = {})
        commit(:post, "customers/#{CGI.escape(customer_id)}/cards/#{CGI.escape(card_id)}", options, options)
      end

      def update_customer(customer_id, options = {})
        commit(:post, "customers/#{CGI.escape(customer_id)}", options, options)
      end

      def unstore(identification, options = {}, deprecated_options = {})
        customer_id, card_id = identification.split('|')

        if options.kind_of?(String)
          ActiveMerchant.deprecated 'Passing the card_id as the 2nd parameter is deprecated. The response authorization includes both the customer_id and the card_id.'
          card_id ||= options
          options = deprecated_options
        end

        commit(:delete, "customers/#{CGI.escape(customer_id)}/cards/#{CGI.escape(card_id)}", nil, options)
      end

      def tokenize_apple_pay_token(apple_pay_payment_token, options = {})
        token_response = api_request(:post, "tokens?pk_token=#{CGI.escape(apple_pay_payment_token.payment_data.to_json)}")
        success = !token_response.key?('error')

        if success && token_response.key?('id')
          Response.new(success, nil, token: token_response)
        else
          Response.new(success, token_response['error']['message'])
        end
      end

      def verify_credentials
        begin
          ssl_get(live_url + 'charges/nonexistent', headers)
        rescue ResponseError => e
          return false if e.response.code.to_i == 401
        end

        true
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((&?three_d_secure\[cryptogram\]=)[\w=]*(&?)), '\1[FILTERED]\2').
          gsub(%r((card\[cryptogram\]=)[^&]+(&?)), '\1[FILTERED]\2').
          gsub(%r((card\[cvc\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[emv_approval_data\]=)[^&]+(&?)), '\1[FILTERED]\2').
          gsub(%r((card\[emv_auth_data\]=)[^&]+(&?)), '\1[FILTERED]\2').
          gsub(%r((card\[encrypted_pin\]=)[^&]+(&?)), '\1[FILTERED]\2').
          gsub(%r((card\[encrypted_pin_key_id\]=)[\w=]+(&?)), '\1[FILTERED]\2').
          gsub(%r((card\[number\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[swipe_data\]=)[^&]+(&?)), '\1[FILTERED]\2')
      end

      def supports_network_tokenization?
        true
      end

      private

      class StripePaymentToken < PaymentToken
        def type
          'stripe'
        end
      end

      def create_source(money, payment, type, options = {})
        post = {}
        add_amount(post, money, options, true)
        post[:type] = type
        if type == 'card'
          add_creditcard(post, payment, options, true)
          add_source_owner(post, payment, options)
        elsif type == 'three_d_secure'
          post[:three_d_secure] = {card: payment}
          post[:redirect] = {return_url: options[:redirect_url]}
        end
        commit(:post, 'sources', post, options)
      end

      def show_source(source_id, options)
        commit(:get, "sources/#{source_id}", nil, options)
      end

      def create_webhook_endpoint(options, events)
        post = {}
        post[:url] = options[:callback_url]
        post[:enabled_events] = events
        post[:connect] = true if options[:stripe_account]
        options.delete(:stripe_account)
        commit(:post, 'webhook_endpoints', post, options)
      end

      def delete_webhook_endpoint(options)
        commit(:delete, "webhook_endpoints/#{options[:webhook_id]}", {}, options)
      end

      def show_webhook_endpoint(options)
        options.delete(:stripe_account)
        commit(:get, "webhook_endpoints/#{options[:webhook_id]}", nil, options)
      end

      def list_webhook_endpoints(options)
        params = {}
        params[:limit] = options[:limit] if options[:limit]
        options.delete(:stripe_account)
        commit(:get, "webhook_endpoints?#{post_data(params)}", nil, options)
      end

      def create_post_for_auth_or_purchase(money, payment, options)
        post = {}

        if payment.is_a?(StripePaymentToken)
          add_payment_token(post, payment, options)
        else
          add_creditcard(post, payment, options)
        end

        add_charge_details(post, money, payment, options)
        post
      end

      # Used internally by Spreedly to populate the charge object for 3DS 1.0 transactions
      def add_charge_details(post, money, payment, options)
        if emv_payment?(payment)
          add_statement_address(post, options)
          add_emv_metadata(post, payment)
        else
          add_amount(post, money, options, true)
          add_customer_data(post, options)
          post[:description] = options[:description]
          post[:statement_descriptor] = options[:statement_description]
          post[:statement_descriptor_suffix] = options[:statement_descriptor_suffix] if options[:statement_descriptor_suffix]
          post[:receipt_email] = options[:receipt_email] if options[:receipt_email]
          add_customer(post, payment, options)
          add_flags(post, options)
        end

        add_metadata(post, options)
        add_application_fee(post, options)
        add_exchange_rate(post, options)
        add_destination(post, options)
        add_level_three(post, options)
        add_connected_account(post, options)
        post
      end

      def add_amount(post, money, options, include_currency = false)
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency.downcase if include_currency
      end

      def add_application_fee(post, options)
        post[:application_fee] = options[:application_fee] if options[:application_fee]
      end

      def add_exchange_rate(post, options)
        post[:exchange_rate] = options[:exchange_rate] if options[:exchange_rate]
      end

      def add_destination(post, options)
        if options[:destination]
          post[:destination] = {}
          post[:destination][:account] = options[:destination]
          post[:destination][:amount] = options[:destination_amount] if options[:destination_amount]
        end
      end

      def add_level_three(post, options)
        level_three = {}

        copy_when_present(level_three, [:merchant_reference], options)
        copy_when_present(level_three, [:customer_reference], options)
        copy_when_present(level_three, [:shipping_address_zip], options)
        copy_when_present(level_three, [:shipping_from_zip], options)
        copy_when_present(level_three, [:shipping_amount], options)
        copy_when_present(level_three, [:line_items], options)

        post[:level3] = level_three unless level_three.empty?
      end

      def add_expand_parameters(post, options)
        post[:expand] ||= []
        post[:expand].concat(Array.wrap(options[:expand]).map(&:to_sym)).uniq!
      end

      def add_external_account(post, card_params, payment)
        external_account = {}
        external_account[:object] = 'card'
        external_account[:currency] = (options[:currency] || currency(payment)).downcase
        post[:external_account] = external_account.merge(card_params[:card])
      end

      def add_customer_data(post, options)
        metadata_options = %i[description ip user_agent referrer]
        post.update(options.slice(*metadata_options))

        post[:external_id] = options[:order_id]
        post[:payment_user_agent] = "Stripe/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
      end

      def add_address(post, options)
        return unless post[:card]&.kind_of?(Hash)

        if address = options[:billing_address] || options[:address]
          post[:card][:address_line1] = address[:address1] if address[:address1]
          post[:card][:address_line2] = address[:address2] if address[:address2]
          post[:card][:address_country] = address[:country] if address[:country]
          post[:card][:address_zip] = address[:zip] if address[:zip]
          post[:card][:address_state] = address[:state] if address[:state]
          post[:card][:address_city] = address[:city] if address[:city]
        end
      end

      def add_statement_address(post, options)
        return unless statement_address = options[:statement_address]
        return unless %i[address1 city zip state].all? { |key| statement_address[key].present? }

        post[:statement_address] = {}
        post[:statement_address][:line1] = statement_address[:address1]
        post[:statement_address][:line2] = statement_address[:address2] if statement_address[:address2].present?
        post[:statement_address][:city] = statement_address[:city]
        post[:statement_address][:postal_code] = statement_address[:zip]
        post[:statement_address][:state] = statement_address[:state]
      end

      def add_creditcard(post, creditcard, options, use_sources = false)
        card = {}
        if emv_payment?(creditcard)
          add_emv_creditcard(post, creditcard.icc_data)
          post[:card][:read_method] = 'contactless' if creditcard.read_method == 'contactless'
          post[:card][:read_method] = 'contactless_magstripe_mode' if creditcard.read_method == 'contactless_magstripe'
          if creditcard.encrypted_pin_cryptogram.present? && creditcard.encrypted_pin_ksn.present?
            post[:card][:encrypted_pin] = creditcard.encrypted_pin_cryptogram
            post[:card][:encrypted_pin_key_id] = creditcard.encrypted_pin_ksn
          end
        elsif creditcard.respond_to?(:number)
          if creditcard.respond_to?(:track_data) && creditcard.track_data.present?
            card[:swipe_data] = creditcard.track_data
            if creditcard.respond_to?(:read_method)
              card[:fallback_reason] = 'no_chip' if creditcard.read_method == 'fallback_no_chip'
              card[:fallback_reason] = 'chip_error' if creditcard.read_method == 'fallback_chip_error'
              card[:read_method] = 'contactless_magstripe_mode' if creditcard.read_method == 'contactless_magstripe'
            end
          else
            card[:number] = creditcard.number
            card[:exp_month] = creditcard.month
            card[:exp_year] = creditcard.year
            card[:cvc] = creditcard.verification_value if creditcard.verification_value?
            card[:name] = creditcard.name if creditcard.name && !use_sources
          end

          if creditcard.is_a?(NetworkTokenizationCreditCard)
            card[:cryptogram] = creditcard.payment_cryptogram
            card[:eci] = creditcard.eci.rjust(2, '0') if creditcard.eci =~ /^[0-9]+$/
            card[:tokenization_method] = creditcard.source.to_s
          end
          post[:card] = card

          add_address(post, options) unless use_sources
        elsif creditcard.kind_of?(String)
          if options[:track_data]
            card[:swipe_data] = options[:track_data]
          elsif creditcard.include?('|')
            customer_id, card_id = creditcard.split('|')
            card = card_id
            post[:customer] = customer_id
          else
            card = creditcard
          end
          post[:card] = card
        end
      end

      def add_emv_creditcard(post, icc_data, options = {})
        post[:card] = { emv_auth_data: icc_data }
      end

      def add_payment_token(post, token, options = {})
        post[:card] = token.payment_data['id']
      end

      def add_customer(post, payment, options)
        post[:customer] = options[:customer] if options[:customer] && !payment.respond_to?(:number)
      end

      def add_flags(post, options)
        post[:uncaptured] = true if options[:uncaptured]
        post[:recurring] = true if options[:eci] == 'recurring' || options[:recurring]
      end

      def add_metadata(post, options = {})
        post[:metadata] ||= {}
        post[:metadata].merge!(options[:metadata]) if options[:metadata]
        post[:metadata][:email] = options[:email] if options[:email]
        post[:metadata][:order_id] = options[:order_id] if options[:order_id]
        post.delete(:metadata) if post[:metadata].empty?
      end

      def add_emv_metadata(post, creditcard)
        post[:metadata] ||= {}
        post[:metadata][:card_read_method] = creditcard.read_method if creditcard.respond_to?(:read_method)
      end

      def add_source_owner(post, creditcard, options)
        post[:owner] = {}
        post[:owner][:name] = creditcard.name if creditcard.name
        post[:owner][:email] = options[:email] if options[:email]

        if address = options[:billing_address] || options[:address]
          owner_address = {}
          owner_address[:line1] = address[:address1] if address[:address1]
          owner_address[:line2] = address[:address2] if address[:address2]
          owner_address[:country] = address[:country] if address[:country]
          owner_address[:postal_code] = address[:zip] if address[:zip]
          owner_address[:state] = address[:state] if address[:state]
          owner_address[:city] = address[:city] if address[:city]

          post[:owner][:phone] = address[:phone] if address[:phone]
          post[:owner][:address] = owner_address
        end
      end

      def add_connected_account(post, options = {})
        return unless options[:transfer_destination]

        post[:transfer_data] = { destination: options[:transfer_destination] }
        post[:transfer_data][:amount] = options[:transfer_amount] if options[:transfer_amount]
        post[:on_behalf_of] = options[:on_behalf_of] if options[:on_behalf_of]
        post[:transfer_group] = options[:transfer_group] if options[:transfer_group]
        post[:application_fee_amount] = options[:application_fee_amount] if options[:application_fee_amount]
      end

      def parse(body)
        JSON.parse(body)
      end

      def post_data(params)
        return nil unless params

        flatten_params([], params).join('&')
      end

      def flatten_params(flattened, params, prefix = nil)
        params.each do |key, value|
          next if value != false && value.blank?

          flattened_key = prefix.nil? ? key : "#{prefix}[#{key}]"
          if value.is_a?(Hash)
            flatten_params(flattened, value, flattened_key)
          elsif value.is_a?(Array)
            flatten_array(flattened, value, flattened_key)
          else
            flattened << "#{flattened_key}=#{CGI.escape(value.to_s)}"
          end
        end
        flattened
      end

      def flatten_array(flattened, array, prefix)
        array.each_with_index do |item, idx|
          key = "#{prefix}[#{idx}]"
          if item.is_a?(Hash)
            flatten_params(flattened, item, key)
          elsif item.is_a?(Array)
            flatten_array(flattened, item, key)
          else
            flattened << "#{key}=#{CGI.escape(item.to_s)}"
          end
        end
      end

      def headers(options = {})
        key = options[:key] || @api_key
        idempotency_key = options[:idempotency_key]

        headers = {
          'Authorization' => 'Basic ' + Base64.strict_encode64(key.to_s + ':').strip,
          'User-Agent' => "Stripe/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          'Stripe-Version' => api_version(options),
          'X-Stripe-Client-User-Agent' => stripe_client_user_agent(options),
          'X-Stripe-Client-User-Metadata' => {ip: options[:ip]}.to_json
        }
        headers['Idempotency-Key'] = idempotency_key if idempotency_key
        headers['Stripe-Account'] = options[:stripe_account] if options[:stripe_account]
        headers
      end

      def stripe_client_user_agent(options)
        return user_agent unless options[:application]

        JSON.dump(JSON.parse(user_agent).merge!({application: options[:application]}))
      end

      def api_version(options)
        options[:version] || @options[:version] || self.class::DEFAULT_API_VERSION
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, self.live_url + endpoint, post_data(parameters), headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(method, url, parameters = nil, options = {})
        add_expand_parameters(parameters, options) if parameters
        response = api_request(method, url, parameters, options)
        response['webhook_id'] = options[:webhook_id] if options[:webhook_id]
        success = success_from(response, options)

        card = card_from_response(response)
        avs_code = AVS_CODE_TRANSLATOR["line1: #{card['address_line1_check']}, zip: #{card['address_zip_check']}"]
        cvc_code = CVC_CODE_TRANSLATOR[card['cvc_check']]

        Response.new(success,
          message_from(success, response),
          response,
          test: response_is_test?(response),
          authorization: authorization_from(success, url, method, response),
          avs_result: { code: avs_code },
          cvv_result: cvc_code,
          emv_authorization: emv_authorization_from_response(response),
          error_code: success ? nil : error_code_from(response)
        )
      end

      def authorization_from(success, url, method, response)
        return response.fetch('error', {})['charge'] unless success

        if url == 'customers'
          [response['id'], response.dig('sources', 'data').first&.dig('id')].join('|')
        elsif method == :post && (url.match(/customers\/.*\/cards/) || url.match(/payment_methods\/.*\/attach/))
          [response['customer'], response['id']].join('|')
        else
          response['id']
        end
      end

      def message_from(success, response)
        success ? 'Transaction approved' : response.fetch('error', {'message' => 'No error details'})['message']
      end

      def success_from(response, options)
        !response.key?('error') && response['status'] != 'failed'
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Stripe API.  Please contact support@stripe.com if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'error' => {
            'message' => msg
          }
        }
      end

      def response_is_test?(response)
        if response.has_key?('livemode')
          !response['livemode']
        elsif response['charge'].is_a?(Hash) && response['charge'].has_key?('livemode')
          !response['charge']['livemode']
        else
          false
        end
      end

      def emv_payment?(payment)
        payment.respond_to?(:emv?) && payment.emv?
      end

      def quickchip_payment?(payment)
        payment.respond_to?(:read_method) && payment.read_method == 'contact_quickchip'
      end

      def card_from_response(response)
        response['card'] || response['active_card'] || response['source'] || {}
      end

      def emv_authorization_from_response(response)
        return response['error']['emv_auth_data'] if response['error']

        card_from_response(response)['emv_auth_data']
      end

      def error_code_from(response)
        return STANDARD_ERROR_CODE_MAPPING['processing_error'] unless response['error']

        code = response['error']['code']
        decline_code = response['error']['decline_code'] if code == 'card_declined'

        error_code = STANDARD_ERROR_CODE_MAPPING[decline_code]
        error_code ||= STANDARD_ERROR_CODE_MAPPING[code]
        error_code
      end

      def tokenize_bank_account(bank_account, options = {})
        account_holder_type = BANK_ACCOUNT_HOLDER_TYPE_MAPPING[bank_account.account_holder_type]

        post = {
          bank_account: {
            account_number: bank_account.account_number,
            country: 'US',
            currency: 'usd',
            routing_number: bank_account.routing_number,
            name: bank_account.name,
            account_holder_type: account_holder_type
          }
        }

        token_response = api_request(:post, "tokens?#{post_data(post)}")
        success = token_response['error'].nil?

        if success && token_response['id']
          Response.new(success, nil, token: token_response)
        else
          Response.new(success, token_response['error']['message'])
        end
      end

      def ach?(payment_method)
        case payment_method
        when String, nil
          false
        else
          card_brand(payment_method) == 'check'
        end
      end

      def auth_minimum_amount(options)
        return 100 unless options[:currency]

        return MINIMUM_AUTHORIZE_AMOUNTS[options[:currency].upcase] || 100
      end

      def copy_when_present(dest, dest_path, source, source_path = nil)
        source_path ||= dest_path
        source_path.each do |key|
          return nil unless source[key]

          source = source[key]
        end

        if source
          dest_path.first(dest_path.size - 1).each do |key|
            dest[key] ||= {}
            dest = dest[key]
          end
          dest[dest_path.last] = source
        end
      end
    end
  end
end
