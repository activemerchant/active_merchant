module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CheckoutV2Gateway < Gateway
      self.display_name = 'Checkout.com Unified Payments'
      self.homepage_url = 'https://www.checkout.com/'
      self.live_url = 'https://api.checkout.com'
      self.test_url = 'https://api.sandbox.checkout.com'

      self.supported_countries = %w[AD AE AR AT AU BE BG BH BR CH CL CN CO CY CZ DE DK EE EG ES FI FR GB GR HK HR HU IE IS IT JO JP KW LI LT LU LV MC MT MX MY NL NO NZ OM PE PL PT QA RO SA SE SG SI SK SM TR US]
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express diners_club maestro discover jcb mada bp_plus]
      self.currencies_without_fractions = %w(BIF DJF GNF ISK KMF XAF CLF XPF JPY PYG RWF KRW VUV VND XOF)
      self.currencies_with_three_decimal_places = %w(BHD LYD JOD KWD OMR TND)

      LIVE_ACCESS_TOKEN_URL = 'https://access.checkout.com/connect/token'
      TEST_ACCESS_TOKEN_URL = 'https://access.sandbox.checkout.com/connect/token'

      def initialize(options = {})
        options.has_key?(:secret_key) ? requires!(options, :secret_key) : requires!(options, :client_id, :client_secret)

        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        build_auth_or_purchase(post, amount, payment_method, options)

        commit(:purchase, post, options)
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        post[:capture] = false
        build_auth_or_purchase(post, amount, payment_method, options)

        options[:incremental_authorization] ? commit(:incremental_authorize, post, options, options[:incremental_authorization]) : commit(:authorize, post, options)
      end

      def capture(amount, authorization, options = {})
        post = {}
        post[:capture_type] = options[:capture_type] || 'Final'
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        add_shipping_address(post, options)
        add_metadata(post, options)

        commit(:capture, post, options, authorization)
      end

      def credit(amount, payment, options = {})
        post = {}
        add_processing_channel(post, options)
        add_invoice(post, amount, options)
        add_payment_method(post, payment, options, :destination)
        add_source(post, options)
        add_instruction_data(post, options)
        add_payout_sender_data(post, options)
        add_payout_destination_data(post, options)

        commit(:credit, post, options)
      end

      def void(authorization, _options = {})
        post = {}
        add_metadata(post, options)

        commit(:void, post, options, authorization)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_customer_data(post, options)
        add_metadata(post, options)

        commit(:refund, post, options, authorization)
      end

      def verify(credit_card, options = {})
        authorize(0, credit_card, options)
      end

      def inquire(authorization, options = {})
        verify_payment(authorization, {})
      end

      def verify_payment(authorization, options = {})
        commit(:verify_payment, nil, options, authorization, :get)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: )[^\\]*/i, '\1[FILTERED]').
          gsub(/("number\\":\\")\d+/, '\1[FILTERED]').
          gsub(/("cvv\\":\\")\d+/, '\1[FILTERED]').
          gsub(/("cryptogram\\":\\")\w+/, '\1[FILTERED]').
          gsub(/(source\\":\{.*\\"token\\":\\")\d+/, '\1[FILTERED]').
          gsub(/("token\\":\\")\w+/, '\1[FILTERED]').
          gsub(/("access_token\\?"\s*:\s*\\?")[^"]*\w+/, '\1[FILTERED]')
      end

      def store(payment_method, options = {})
        post = {}
        MultiResponse.run do |r|
          if payment_method.is_a?(NetworkTokenizationCreditCard)
            r.process { verify(payment_method, options) }
            break r unless r.success?

            r.params['source']['customer'] = r.params['customer']
            r.process { response(:store, true, r.params['source']) }
          else
            r.process { tokenize(payment_method, options) }
            break r unless r.success?

            token = r.params['token']
            add_payment_method(post, token, options)
            post.merge!(post.delete(:source))
            add_customer_data(post, options)
            add_shipping_address(post, options)
            r.process { commit(:store, post, options) }
          end
        end
      end

      def unstore(id, options = {})
        commit(:unstore, nil, options, id, :delete)
      end

      private

      def build_auth_or_purchase(post, amount, payment_method, options)
        add_invoice(post, amount, options)
        add_authorization_type(post, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_extra_customer_data(post, payment_method, options)
        add_shipping_address(post, options)
        add_stored_credential_options(post, options)
        add_transaction_data(post, options)
        add_3ds(post, options)
        add_metadata(post, options, payment_method)
        add_processing_channel(post, options)
        add_marketplace_data(post, options)
        add_recipient_data(post, options)
        add_processing_data(post, options)
        add_payment_sender_data(post, options)
        add_risk_data(post, options)
        truncate_amex_reference_id(post, options, payment_method)
      end

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

      def truncate_amex_reference_id(post, options, payment_method)
        post[:reference] = truncate(options[:order_id], 30) if payment_method.respond_to?(:brand) && payment_method.brand == 'american_express'
      end

      def add_recipient_data(post, options)
        return unless options[:recipient].is_a?(Hash)

        recipient = options[:recipient]

        post[:recipient] = {}
        post[:recipient][:dob] = recipient[:dob] if recipient[:dob]
        post[:recipient][:zip] = recipient[:zip] if recipient[:zip]
        post[:recipient][:account_number] = recipient[:account_number] if recipient[:account_number]
        post[:recipient][:first_name] = recipient[:first_name] if recipient[:first_name]
        post[:recipient][:last_name] = recipient[:last_name] if recipient[:last_name]

        if address = recipient[:address]
          address1 = address[:address1] || address[:address_line1]
          address2 = address[:address2] || address[:address_line2]

          post[:recipient][:address] = {}
          post[:recipient][:address][:address_line1] = address1 if address1
          post[:recipient][:address][:address_line2] = address2 if address2
          post[:recipient][:address][:city] = address[:city] if address[:city]
          post[:recipient][:address][:state] = address[:state] if address[:state]
          post[:recipient][:address][:zip] = address[:zip] if address[:zip]
          post[:recipient][:address][:country] = address[:country] if address[:country]
        end
      end

      def add_processing_data(post, options)
        return unless options[:processing].is_a?(Hash)

        post[:processing] = options[:processing]
      end

      def add_risk_data(post, options)
        return unless options[:risk].is_a?(Hash)

        risk = options[:risk]
        post[:risk] = {} unless risk.empty?

        if risk[:enabled].to_s == 'true'
          post[:risk][:enabled] = true
          post[:risk][:device_session_id] = risk[:device_session_id] if risk[:device_session_id]
        elsif risk[:enabled].to_s == 'false'
          post[:risk][:enabled] = false
        end
      end

      def add_payment_sender_data(post, options)
        return unless options[:sender].is_a?(Hash)

        sender = options[:sender]

        post[:sender] = {}
        post[:sender][:type] = sender[:type] if sender[:type]
        post[:sender][:first_name] = sender[:first_name] if sender[:first_name]
        post[:sender][:last_name] = sender[:last_name] if sender[:last_name]
        post[:sender][:dob] = sender[:dob] if sender[:dob]
        post[:sender][:reference] = sender[:reference] if sender[:reference]
        post[:sender][:company_name] = sender[:company_name] if sender[:company_name]

        if address = sender[:address]
          address1 = address[:address1] || address[:address_line1]
          address2 = address[:address2] || address[:address_line2]

          post[:sender][:address] = {}
          post[:sender][:address][:address_line1] = address1 if address1
          post[:sender][:address][:address_line2] = address2 if address2
          post[:sender][:address][:city] = address[:city] if address[:city]
          post[:sender][:address][:state] = address[:state] if address[:state]
          post[:sender][:address][:zip] = address[:zip] if address[:zip]
          post[:sender][:address][:country] = address[:country] if address[:country]
        end

        if identification = sender[:identification]
          post[:sender][:identification] = {}
          post[:sender][:identification][:type] = identification[:type] if identification[:type]
          post[:sender][:identification][:number] = identification[:number] if identification[:number]
          post[:sender][:identification][:issuing_country] = identification[:issuing_country] if identification[:issuing_country]
        end
      end

      def add_authorization_type(post, options)
        post[:authorization_type] = options[:authorization_type] if options[:authorization_type]
      end

      def add_metadata(post, options, payment_method = nil)
        post[:metadata] = {} unless post[:metadata]
        post[:metadata].merge!(options[:metadata]) if options[:metadata]
        post[:metadata][:udf1] = 'mada' if payment_method.try(:brand) == 'mada'
      end

      def add_payment_method(post, payment_method, options, key = :source)
        # the key = :destination when this method is called in def credit
        post[key] = {}
        case payment_method
        when NetworkTokenizationCreditCard
          token_type = token_type_from(payment_method)
          cryptogram = payment_method.payment_cryptogram
          eci = payment_method.eci || options[:eci]
          eci ||= '05' if token_type == 'vts'

          post[key][:type] = 'network_token'
          post[key][:token] = payment_method.number
          post[key][:token_type] = token_type
          post[key][:cryptogram] = cryptogram if cryptogram
          post[key][:eci] = eci if eci
        when ->(pm) { pm.try(:credit_card?) }
          post[key][:type] = 'card'
          post[key][:name] = payment_method.name
          post[key][:number] = payment_method.number
          post[key][:cvv] = payment_method.verification_value unless options[:funds_transfer_type]
          post[key][:stored] = 'true' if options[:card_on_file] == true

          # because of the way the key = is implemented in the method signature, some of the destination
          # data will be added here, some in the destination specific method below.
          # at first i was going to move this, but since this data is coming from the payment method
          # i think it makes sense to leave it
          if options[:account_holder_type]
            post[key][:account_holder] = {}
            post[key][:account_holder][:type] = options[:account_holder_type]

            if options[:account_holder_type] == 'corporate' || options[:account_holder_type] == 'government'
              post[key][:account_holder][:company_name] = payment_method.name if payment_method.respond_to?(:name)
            else
              post[key][:account_holder][:first_name] = payment_method.first_name if payment_method.first_name
              post[key][:account_holder][:last_name] = payment_method.last_name if payment_method.last_name
            end
          else
            post[key][:first_name] = payment_method.first_name if payment_method.first_name
            post[key][:last_name] = payment_method.last_name if payment_method.last_name
          end
        end
        if payment_method.is_a?(String)
          if /tok/.match?(payment_method)
            post[:type] = 'token'
            post[:token] = payment_method
          elsif /src/.match?(payment_method)
            post[key][:type] = 'id'
            post[key][:id] = payment_method
          else
            add_source(post, options)
          end
        elsif payment_method.try(:year)
          post[key][:expiry_year] = format(payment_method.year, :four_digits)
          post[key][:expiry_month] = format(payment_method.month, :two_digits)
        end
      end

      def add_source(post, options)
        post[:source] = {}
        post[:source][:type] = options[:source_type] if options[:source_type]
        post[:source][:id] = options[:source_id] if options[:source_id]
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

      # created a separate method for these fields because they should not be included
      # in all transaction types that include methods with source and customer fields
      def add_extra_customer_data(post, payment_method, options)
        post[:source][:phone] = {}
        post[:source][:phone][:number] = options[:phone] || options.dig(:billing_address, :phone) || options.dig(:billing_address, :phone_number)
        post[:source][:phone][:country_code] = options[:phone_country_code] if options[:phone_country_code]
        post[:customer][:name] = payment_method.name if payment_method.respond_to?(:name)
      end

      def add_shipping_address(post, options)
        if address = options[:shipping_address]
          post[:shipping] = {}
          post[:shipping][:address] = {}
          post[:shipping][:address][:address_line1] = address[:address1] unless address[:address1].blank?
          post[:shipping][:address][:address_line2] = address[:address2] unless address[:address2].blank?
          post[:shipping][:address][:city] = address[:city] unless address[:city].blank?
          post[:shipping][:address][:state] = address[:state] unless address[:state].blank?
          post[:shipping][:address][:country] = address[:country] unless address[:country].blank?
          post[:shipping][:address][:zip] = address[:zip] unless address[:zip].blank?
        end
      end

      def add_transaction_data(post, options = {})
        post[:payment_type] = 'Regular' if options[:transaction_indicator] == 1
        post[:payment_type] = 'Recurring' if options[:transaction_indicator] == 2
        post[:payment_type] = 'MOTO' if options[:transaction_indicator] == 3 || options.dig(:metadata, :manual_entry)
        post[:previous_payment_id] = options[:previous_charge_id] if options[:previous_charge_id]
      end

      def merchant_initiated_override(post, options)
        post[:payment_type] ||= 'Regular'
        post[:merchant_initiated] = true
        post[:source][:stored] = true
        post[:previous_payment_id] = options[:merchant_initiated_transaction_id]
      end

      def add_stored_credentials_using_normalized_fields(post, options)
        if options[:stored_credential][:initiator] == 'cardholder'
          post[:merchant_initiated] = false
        else
          post[:source][:stored] = true
          post[:previous_payment_id] = options[:stored_credential][:network_transaction_id] if options[:stored_credential][:network_transaction_id]
          post[:merchant_initiated] = true
        end
      end

      def add_stored_credential_options(post, options = {})
        return unless options[:stored_credential]

        post[:payment_type] = options[:stored_credential][:reason_type]&.capitalize

        if options[:merchant_initiated_transaction_id]
          merchant_initiated_override(post, options)
        else
          add_stored_credentials_using_normalized_fields(post, options)
        end
      end

      def add_3ds(post, options)
        if options[:three_d_secure] || options[:execute_threed]
          post[:'3ds'] = {}
          post[:'3ds'][:enabled] = true
          post[:success_url] = options[:callback_url] if options[:callback_url]
          post[:failure_url] = options[:callback_url] if options[:callback_url]
          post[:'3ds'][:attempt_n3d] = options[:attempt_n3d] if options[:attempt_n3d]
          post[:'3ds'][:challenge_indicator] = options[:challenge_indicator] if options[:challenge_indicator]
          post[:'3ds'][:exemption] = options[:exemption] if options[:exemption]
        end

        if options[:three_d_secure]
          post[:'3ds'][:eci] = options[:three_d_secure][:eci] if options[:three_d_secure][:eci]
          post[:'3ds'][:cryptogram] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
          post[:'3ds'][:version] = options[:three_d_secure][:version] if options[:three_d_secure][:version]
          post[:'3ds'][:xid] = options[:three_d_secure][:ds_transaction_id] || options[:three_d_secure][:xid]
          post[:'3ds'][:status] = options[:three_d_secure][:authentication_response_status]
        end
      end

      def add_processing_channel(post, options)
        post[:processing_channel_id] = options[:processing_channel_id] if options[:processing_channel_id]
      end

      def add_instruction_data(post, options)
        post[:instruction] = {}
        post[:instruction][:funds_transfer_type] = options[:funds_transfer_type] || 'FD'
        post[:instruction][:purpose] = options[:instruction_purpose] if options[:instruction_purpose]
      end

      def add_payout_sender_data(post, options)
        return unless options[:payout] == true

        post[:sender] = {
          # options for type are individual, corporate, or government
          type: options[:sender][:type],
          # first and last name required if sent by type: individual
          first_name: options[:sender][:first_name],
          middle_name: options[:sender][:middle_name],
          last_name: options[:sender][:last_name],
          # company name required if sent by type: corporate or government
          company_name: options[:sender][:company_name],
          # these are required fields for payout, may not work if address is blank or different than cardholder(option for sender to be a company or government).
          # may need to still include in GSF hash.

          address: {
            address_line1: options.dig(:sender, :address, :address1),
            address_line2: options.dig(:sender, :address, :address2),
            city: options.dig(:sender, :address, :city),
            state: options.dig(:sender, :address, :state),
            country: options.dig(:sender, :address, :country),
            zip: options.dig(:sender, :address, :zip)
          }.compact,
          reference: options[:sender][:reference],
          reference_type: options[:sender][:reference_type],
          source_of_funds: options[:sender][:source_of_funds],
          # identification object is conditional. required when card metadata issuer_country = AR, BR, CO, or PR
          # checkout docs say PR (Peru), but PR is puerto rico and PE is Peru so yikes
          identification: {
            type: options.dig(:sender, :identification, :type),
            number: options.dig(:sender, :identification, :number),
            issuing_country: options.dig(:sender, :identification, :issuing_country),
            date_of_expiry: options.dig(:sender, :identification, :date_of_expiry)
          }.compact,
          date_of_birth: options[:sender][:date_of_birth],
          country_of_birth: options[:sender][:country_of_birth],
          nationality: options[:sender][:nationality]
        }.compact
      end

      def add_payout_destination_data(post, options)
        return unless options[:payout] == true

        post[:destination] ||= {}
        post[:destination][:account_holder] ||= {}
        post[:destination][:account_holder][:email] = options[:destination][:account_holder][:email] if options[:destination][:account_holder][:email]
        post[:destination][:account_holder][:date_of_birth] = options[:destination][:account_holder][:date_of_birth] if options[:destination][:account_holder][:date_of_birth]
        post[:destination][:account_holder][:country_of_birth] = options[:destination][:account_holder][:country_of_birth] if options[:destination][:account_holder][:country_of_birth]
        # below fields only required during a card to card payout
        post[:destination][:account_holder][:phone] = {}
        post[:destination][:account_holder][:phone][:country_code] = options.dig(:destination, :account_holder, :phone, :country_code) if options.dig(:destination, :account_holder, :phone, :country_code)
        post[:destination][:account_holder][:phone][:number] = options.dig(:destination, :account_holder, :phone, :number) if options.dig(:destination, :account_holder, :phone, :number)

        post[:destination][:account_holder][:identification] = {}
        post[:destination][:account_holder][:identification][:type] = options.dig(:destination, :account_holder, :identification, :type) if options.dig(:destination, :account_holder, :identification, :type)
        post[:destination][:account_holder][:identification][:number] = options.dig(:destination, :account_holder, :identification, :number) if options.dig(:destination, :account_holder, :identification, :number)
        post[:destination][:account_holder][:identification][:issuing_country] = options.dig(:destination, :account_holder, :identification, :issuing_country) if options.dig(:destination, :account_holder, :identification, :issuing_country)
        post[:destination][:account_holder][:identification][:date_of_expiry] = options.dig(:destination, :account_holder, :identification, :date_of_expiry) if options.dig(:destination, :account_holder, :identification, :date_of_expiry)

        if address = options[:billing_address] || options[:address] # destination address will come from the tokenized card billing address
          post[:destination][:account_holder][:billing_address] = {}
          post[:destination][:account_holder][:billing_address][:address_line1] = address[:address1] unless address[:address1].blank?
          post[:destination][:account_holder][:billing_address][:address_line2] = address[:address2] unless address[:address2].blank?
          post[:destination][:account_holder][:billing_address][:city] = address[:city] unless address[:city].blank?
          post[:destination][:account_holder][:billing_address][:state] = address[:state] unless address[:state].blank?
          post[:destination][:account_holder][:billing_address][:country] = address[:country] unless address[:country].blank?
          post[:destination][:account_holder][:billing_address][:zip] = address[:zip] unless address[:zip].blank?
        end
      end

      def add_marketplace_data(post, options)
        if options[:marketplace]
          post[:marketplace] = {}
          post[:marketplace][:sub_entity_id] = options[:marketplace][:sub_entity_id] if options[:marketplace][:sub_entity_id]
        end
      end

      def access_token_header
        {
          'Authorization' => "Basic #{Base64.encode64("#{@options[:client_id]}:#{@options[:client_secret]}").delete("\n")}",
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      def access_token_url
        test? ? TEST_ACCESS_TOKEN_URL : LIVE_ACCESS_TOKEN_URL
      end

      def expires_date_with_extra_range(expires_in)
        # Two minutes are subtracted from the expires_in time to generate the expires date
        # in order to prevent any transaction from failing due to using an access_token
        # that is very close to expiring.
        # e.g. the access_token has one second left to expire and the lag when the transaction
        # use an already expired access_token
        (DateTime.now + (expires_in - 120).seconds).strftime('%Q').to_i
      end

      def setup_access_token
        response = parse(ssl_post(access_token_url, 'grant_type=client_credentials', access_token_header))
        @options[:access_token] = response['access_token']
        @options[:expires] = expires_date_with_extra_range(response['expires_in']) if response['expires_in'] && response['expires_in'] > 0

        Response.new(
          access_token_valid?,
          message_from(access_token_valid?, response, {}),
          response.merge({ expires: @options[:expires] }),
          test: test?,
          error_code: error_code_from(access_token_valid?, response, {})
        )
      rescue ResponseError => e
        raise OAuthResponseError.new(e)
      end

      def access_token_valid?
        @options[:access_token].present? && @options[:expires].to_i > DateTime.now.strftime('%Q').to_i
      end

      def perform_request(action, post, options, authorization = nil, method = :post)
        begin
          raw_response = ssl_request(method, url(action, authorization), post.nil? || post.empty? ? nil : post.to_json, headers(action, options))
          response = parse(raw_response)
          response['id'] = response['_links']['payment']['href'].split('/')[-1] if action == :capture && response.key?('_links')
        rescue ResponseError => e
          @options[:access_token] = '' if e.response.code == '401' && !@options[:secret_key]

          raise unless e.response.code.to_s =~ /4\d\d/

          response = parse(e.response.body, error: e.response)
        end

        succeeded = success_from(action, response)

        response(action, succeeded, response, options)
      end

      def commit(action, post, options, authorization = nil, method = :post)
        MultiResponse.run do |r|
          r.process { setup_access_token } unless @options[:secret_key] || access_token_valid?
          r.process { perform_request(action, post, options, authorization, method) }
        end
      end

      def response(action, succeeded, response, options = {}, source_id = nil)
        authorization = authorization_from(response) unless action == :unstore
        body = action == :unstore ? { response_code: response.to_s } : response
        Response.new(
          succeeded,
          message_from(succeeded, response, options),
          body,
          authorization: authorization,
          error_code: error_code_from(succeeded, body, options),
          test: test?,
          avs_result: avs_result(response),
          cvv_result: cvv_result(response)
        )
      end

      def headers(action, options)
        auth_token = @options[:access_token] ? "Bearer #{@options[:access_token]}" : @options[:secret_key]
        auth_token = @options[:public_key] if action == :tokens
        headers = {
          'Authorization' => auth_token,
          'Content-Type' => 'application/json;charset=UTF-8'
        }
        headers['Cko-Idempotency-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def tokenize(payment_method, options = {})
        post = {}
        add_authorization_type(post, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        commit(:tokens, post[:source], options)
      end

      def url(action, authorization)
        case action
        when :authorize, :purchase, :credit
          "#{base_url}/payments"
        when :unstore, :store
          "#{base_url}/instruments/#{authorization}"
        when :capture
          "#{base_url}/payments/#{authorization}/captures"
        when :refund
          "#{base_url}/payments/#{authorization}/refunds"
        when :void
          "#{base_url}/payments/#{authorization}/voids"
        when :incremental_authorize
          "#{base_url}/payments/#{authorization}/authorizations"
        when :tokens
          "#{base_url}/tokens"
        when :verify_payment
          "#{base_url}/payments/#{authorization}"
        else
          "#{base_url}/payments/#{authorization}/#{action}"
        end
      end

      def base_url
        test? ? test_url : live_url
      end

      def avs_result(response)
        response.respond_to?(:dig) && response.dig('source', 'avs_check') ? AVSResult.new(code: response['source']['avs_check']) : nil
      end

      def cvv_result(response)
        response.respond_to?(:dig) && response.dig('source', 'cvv_check') ? CVVResult.new(response['source']['cvv_check']) : nil
      end

      def parse(body, error: nil)
        JSON.parse(body)
      rescue JSON::ParserError
        response = {
          'error_type' => error&.code,
          'message' => 'Invalid JSON response received from Checkout.com Unified Payments Gateway. Please contact Checkout.com if you continue to receive this message.',
          'raw_response' => scrub(body)
        }
        response['error_codes'] = [error&.message] if error&.message
        response
      end

      def success_from(action, response)
        return response['status'] == 'Pending' if action == :credit
        return true if action == :unstore && response == 204

        store_response = response['token'] || response['id']
        return true if store_response && ((action == :tokens && store_response.match(/tok/)) || (action == :store && store_response.match(/src_/)))

        response['response_summary'] == 'Approved' || response['approved'] == true || !response.key?('response_summary') && response.key?('action_id')
      end

      def message_from(succeeded, response, options)
        if succeeded
          'Succeeded'
        elsif response['error_type']
          response['error_type'] + ': ' + response['error_codes'].first
        else
          response_summary = response['response_summary'] || response.dig('actions', 0, 'response_summary')
          response_summary || response['response_code'] || response['status'] || response['message'] || 'Unable to read error message'
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

      def error_code_from(succeeded, response, options)
        return if succeeded

        if response['error_type'] && response['error_codes']
          "#{response['error_type']}: #{response['error_codes'].join(', ')}"
        elsif response['error_type']
          response['error_type']
        else
          response_code = response['response_code'] || response.dig('actions', 0, 'response_code')

          STANDARD_ERROR_CODE_MAPPING[response_code]
        end
      end

      def token_type_from(payment_method)
        case payment_method.source
        when :network_token
          payment_method.brand == 'visa' ? 'vts' : 'mdes'
        when :google_pay, :android_pay
          'googlepay'
        when :apple_pay
          'applepay'
        end
      end

      def handle_response(response)
        case response.code.to_i
        # to get the response code after unstore(delete instrument), because the body is nil
        when 200...300
          response.body || response.code
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
