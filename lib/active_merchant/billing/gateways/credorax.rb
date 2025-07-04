module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class CredoraxGateway < Gateway
      class_attribute :test_url, :live_na_url, :live_eu_url

      self.display_name = 'Credorax Gateway'
      self.homepage_url = 'https://www.finaro.com/'

      # NOTE: the IP address you run the remote tests from will need to be
      # whitelisted by Credorax; contact support@credorax.com as necessary to
      # request your IP address be added to the whitelist for your test
      # account.
      self.test_url = 'https://intconsole.credorax.com/intenv/service/gateway'

      # The live URL is assigned on a per merchant basis once certification has passed
      # See the Credorax remote tests for the full certification test suite
      #
      # Once you have your assigned subdomain, you can override the live URL in your application via:
      # ActiveMerchant::Billing::CredoraxGateway.live_url = "https://assigned-subdomain.credorax.net/crax_gate/service/gateway"
      self.live_url = 'https://assigned-subdomain.credorax.net/crax_gate/service/gateway'

      self.supported_countries = %w(AD AT BE BG HR CY CZ DK EE FR DE GI GR GG HU IS IE IM IT JE LV LI LT LU MT MC NO PL PT RO SM SK ES SE CH GB)

      self.default_currency = 'EUR'
      self.currencies_without_fractions = %w(BIF CLP DJF GNF ISK JPY KMF KRW PYG RWF VND VUV XAF XOF XPF)
      self.currencies_with_three_decimal_places = %w(BHD IQD JOD KWD LYD OMR TND)

      self.money_format = :cents
      self.supported_cardtypes = %i[visa master maestro american_express jcb discover diners_club]

      NETWORK_TOKENIZATION_CARD_SOURCE = {
        'apple_pay' => 'applepay',
        'google_pay' => 'googlepay',
        'network_token' => 'vts_mdes_token'
      }

      RESPONSE_MESSAGES = {
        '00' => 'Approved or completed successfully',
        '01' => 'Refer to card issuer',
        '02' => 'Refer to card issuer special condition',
        '03' => 'Invalid merchant',
        '04' => 'Pick up card',
        '05' => 'Do not Honour',
        '06' => 'Error',
        '07' => 'Pick up card special condition',
        '08' => 'Honour with identification',
        '09' => 'Request in progress',
        '10' => 'Approved for partial amount',
        '11' => 'Approved (VIP)',
        '12' => 'Invalid transaction',
        '13' => 'Invalid amount',
        '14' => 'Invalid card number',
        '15' => 'No such issuer',
        '16' => 'Approved, update track 3',
        '17' => 'Customer cancellation',
        '18' => 'Customer dispute',
        '19' => 'Re-enter transaction',
        '20' => 'Invalid response',
        '21' => 'No action taken',
        '22' => 'Suspected malfunction',
        '23' => 'Unacceptable transaction fee',
        '24' => 'File update not supported by receiver',
        '25' => 'No such record',
        '26' => 'Duplicate record update, old record replaced',
        '27' => 'File update field edit error',
        '28' => 'File locked out while update',
        '29' => 'File update error, contact acquirer',
        '30' => 'Format error',
        '31' => 'Issuer signed-off',
        '32' => 'Completed partially',
        '33' => 'Pick-up, expired card',
        '34' => 'Implausible card data',
        '35' => 'Pick-up, card acceptor contact acquirer',
        '36' => 'Pick up, card restricted',
        '37' => 'Pick up, call acquirer security',
        '38' => 'Pick up, Allowable PIN tries exceeded',
        '39' => 'No credit account',
        '40' => 'Requested function not supported',
        '41' => 'Lost Card, Pickup',
        '42' => 'No universal account',
        '43' => 'Pick up, stolen card',
        '44' => 'No investment account',
        '46' => 'Closed account',
        '50' => 'Do not renew',
        '51' => 'Insufficient funds',
        '52' => 'No checking Account',
        '53' => 'No savings account',
        '54' => 'Expired card',
        '55' => 'Incorrect PIN',
        '56' => 'No card record',
        '57' => 'Transaction not allowed for cardholder',
        '58' => 'Transaction not permitted to terminal',
        '59' => 'Suspected Fraud',
        '60' => 'Card acceptor contact acquirer',
        '61' => 'Exceeds withdrawal amount limit',
        '62' => 'Restricted card',
        '63' => 'Security violation',
        '64' => 'Wrong original amount',
        '65' => 'Activity count limit exceeded',
        '66' => 'Call acquirers security department',
        '67' => 'Card to be picked up at ATM',
        '68' => 'Response received too late.',
        '70' => 'PIN data required',
        '71' => 'Decline PIN not changed',
        '75' => 'Pin tries exceeded',
        '76' => 'Wrong PIN, number of PIN tries exceeded',
        '77' => 'Wrong Reference No.',
        '78' => 'Blocked, first used/ Record not found',
        '79' => 'Declined due to lifecycle event',
        '80' => 'Network error',
        '81' => 'PIN cryptographic error',
        '82' => 'Bad CVV/ Declined due to policy event',
        '83' => 'Transaction failed',
        '84' => 'Pre-authorization timed out',
        '85' => 'No reason to decline',
        '86' => 'Cannot verify pin',
        '87' => 'Purchase amount only, no cashback allowed',
        '88' => 'Cryptographic failure',
        '89' => 'Authentication failure',
        '91' => 'Issuer not available',
        '92' => 'Unable to route at acquirer Module',
        '93' => 'Cannot be completed, violation of law',
        '94' => 'Duplicate Transmission',
        '95' => 'Reconcile error / Auth Not found',
        '96' => 'System malfunction',
        '97' => 'Transaction has been declined by the processor',
        'N3' => 'Cash service not available',
        'N4' => 'Cash request exceeds issuer or approved limit',
        'N7' => 'CVV2 failure',
        'R0' => 'Stop Payment Order',
        'R1' => 'Revocation of Authorisation Order',
        'R3' => 'Revocation of all Authorisation Orders',
        '1A' => 'Strong Customer Authentication required'
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :cipher_key)
        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_email(post, options)
        add_3d_secure(post, options)
        add_3ds_2_optional_fields(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_stored_credential(post, options)
        add_processor(post, options)
        add_crypto_currency_type(post, options)

        if options[:aft]
          add_recipient(post, options)
          add_sender(post, options)
        end

        commit(:purchase, post)
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_email(post, options)
        add_3d_secure(post, options)
        add_3ds_2_optional_fields(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_stored_credential(post, options)
        add_account_name_inquiry(post, options)
        add_processor(post, options)
        add_authorization_details(post, options)
        add_crypto_currency_type(post, options)

        if options[:aft]
          add_recipient(post, options)
          add_sender(post, options)
        end

        commit(:authorize, post)
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_processor(post, options)
        add_crypto_currency_type(post, options)
        add_transaction_type(post, options)

        commit(:capture, post)
      end

      def void(authorization, options = {})
        post = {}
        add_customer_data(post, options)
        reference_action = add_reference(post, authorization)
        add_echo(post, options)
        add_submerchant_id(post, options)
        post[:a1] = generate_unique_id
        add_processor(post, options)
        add_crypto_currency_type(post, options)
        add_transaction_type(post, options)

        commit(:void, post, reference_action)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_processor(post, options)
        add_email(post, options)
        add_recipient(post, options)
        add_crypto_currency_type(post, options)
        add_transaction_type(post, options)

        if options[:referral_cft]
          add_customer_name(post, options)
          commit(:referral_cft, post)
        else
          commit(:refund, post)
        end
      end

      def credit(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_email(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_transaction_type(post, options)
        add_processor(post, options)
        add_customer_name(post, options)
        add_crypto_currency_type(post, options)

        commit(:credit, post)
      end

      def verify(payment_method, options = {})
        amount = eligible_for_0_auth?(payment_method, options) ? 0 : 100
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amount, payment_method, options) }
          r.process(:ignore_result) { void(r.authorization, options) } unless eligible_for_0_auth?(payment_method, options)
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((b1=)\d+), '\1[FILTERED]').
          gsub(%r((b5=)\d+), '\1[FILTERED]')
      end

      def add_3ds_2_optional_fields(post, options)
        three_ds = options[:three_ds_2] || {}

        if three_ds.has_key?(:optional)
          three_ds[:optional].each do |key, value|
            normalized_value = normalize(value)
            next if normalized_value.nil?

            next if key == :'3ds_homephonecountry' && !(options[:billing_address] && options[:billing_address][:phone])

            post[key] = normalized_value unless post[key]
          end
        end

        post
      end

      private

      def add_invoice(post, money, options)
        currency = options[:currency] || currency(money)

        post[:a4] = localized_amount(money, currency)
        post[:a1] = generate_unique_id
        post[:a5] = currency
        post[:h9] = options[:order_id]
        post[:i2] = options[:billing_descriptor] if options[:billing_descriptor]
      end

      CARD_TYPES = {
        'visa' => '1',
        'mastercard' => '2',
        'maestro' => '9'
      }

      def add_payment_method(post, payment_method, options)
        post[:c1] = payment_method&.name || '' unless options[:account_name_inquiry].to_s == 'true'
        add_network_tokenization_card(post, payment_method, options) if payment_method.is_a? NetworkTokenizationCreditCard
        post[:b2] = CARD_TYPES[payment_method.brand] || ''
        post[:b1] = payment_method.number
        post[:b5] = payment_method.verification_value
        post[:b4] = format(payment_method.year, :two_digits)
        post[:b3] = format(payment_method.month, :two_digits)
      end

      def eligible_for_0_auth?(payment_method, options = {})
        payment_method.is_a?(CreditCard) && %w(visa master).include?(payment_method.brand) && options[:zero_dollar_auth]
      end

      def add_network_tokenization_card(post, payment_method, options)
        post[:b21] = NETWORK_TOKENIZATION_CARD_SOURCE[payment_method.source.to_s]
        post[:token_eci] = post[:b21] == 'vts_mdes_token' ? '07' : nil
        post[:token_eci] = options[:eci] || payment_method&.eci || (payment_method.brand.to_s == 'master' ? '00' : '07')
        post[:token_crypto] = payment_method&.payment_cryptogram if payment_method.source.to_s == 'network_token'
      end

      def add_stored_credential(post, options)
        add_transaction_type(post, options)
        # if :transaction_type option is not passed, then check for :stored_credential options
        return unless (stored_credential = options[:stored_credential]) && options.dig(:transaction_type).nil?

        if stored_credential[:initiator] == 'merchant'
          case stored_credential[:reason_type]
          when 'recurring'
            post[:a9] = stored_credential[:initial_transaction] ? '1' : '2'
          when 'installment', 'unscheduled'
            post[:a9] = '8'
          end
          post[:g6] = stored_credential[:network_transaction_id] if stored_credential[:network_transaction_id]
        else
          post[:a9] = '9'
        end
      end

      def add_customer_data(post, options)
        post[:d1] = options[:ip] || '127.0.0.1'
        if (billing_address = options[:billing_address])
          post[:c5]   = billing_address[:address1]      if billing_address[:address1]
          post[:c7]   = billing_address[:city]          if billing_address[:city]
          post[:c10]  = billing_address[:zip]           if billing_address[:zip]
          post[:c8]   = billing_address[:state]         if billing_address[:state]
          post[:c9]   = billing_address[:country]       if billing_address[:country]
          post[:c2]   = billing_address[:phone] if billing_address[:phone]
        end
      end

      def add_reference(post, authorization)
        response_id, authorization_code, request_id, action = authorization.split(';')
        post[:g2] = response_id
        post[:g3] = authorization_code
        post[:g4] = request_id
        action || :authorize
      end

      def add_email(post, options)
        post[:c3] = options[:email] || 'unspecified@example.com'
      end

      def add_sender(post, options)
        return unless options[:sender_ref_number] || options[:sender_fund_source] || options[:sender_country_code] || options[:sender_street_address] || options[:sender_city] || options[:sender_state] || options[:sender_first_name] || options[:sender_last_name] || options[:sender_birth_date]

        sender_country_code = options[:sender_country_code]&.length == 3 ? options[:sender_country_code] : Country.find(options[:sender_country_code]).code(:alpha3).value if options[:sender_country_code]
        post[:s15] = sender_country_code
        post[:s17] = options[:sender_ref_number] if options[:sender_ref_number]
        post[:s18] = options[:sender_fund_source] if options[:sender_fund_source]
        post[:s10] = options[:sender_first_name] if options[:sender_first_name]
        post[:s11] = options[:sender_last_name] if options[:sender_last_name]
        post[:s12] = options[:sender_street_address] if options[:sender_street_address]
        post[:s13] = options[:sender_city] if options[:sender_city]
        post[:s14] = options[:sender_state] if options[:sender_state]
        post[:s19] = options[:sender_birth_date] if options[:sender_birth_date]
      end

      def add_recipient(post, options)
        return unless options[:recipient_street_address] || options[:recipient_city] || options[:recipient_province_code] || options[:recipient_country_code] || options[:recipient_first_name] || options[:recipient_last_name] || options[:recipient_postal_code]

        recipient_country_code = options[:recipient_country_code]&.length == 3 ? options[:recipient_country_code] : Country.find(options[:recipient_country_code]).code(:alpha3).value if options[:recipient_country_code]
        post[:j6] = options[:recipient_street_address] if options[:recipient_street_address]
        post[:j7] = options[:recipient_city] if options[:recipient_city]
        post[:j8] = options[:recipient_province_code] if options[:recipient_province_code]
        post[:j12] = options[:recipient_postal_code] if options[:recipient_postal_code]
        post[:j9] = recipient_country_code

        if options[:aft]
          post[:j5] = options[:recipient_first_name] if options[:recipient_first_name]
          post[:j13] = options[:recipient_last_name] if options[:recipient_last_name]
        end
      end

      def add_customer_name(post, options)
        post[:j5] = options[:first_name] if options[:first_name]
        post[:j13] = options[:last_name] if options[:last_name]
      end

      def add_account_name_inquiry(post, options)
        return unless options[:account_name_inquiry].to_s == 'true'

        post[:c22] = options[:first_name] if options[:first_name]
        post[:c23] = options[:last_name] if options[:last_name]
        post[:a9] = '5'
      end

      def add_3d_secure(post, options)
        if (options[:eci] && options[:xid]) || (options[:three_d_secure] && options[:three_d_secure][:version]&.start_with?('1'))
          add_3d_secure_1_data(post, options)
        elsif options[:execute_threed] && options[:three_ds_2]
          three_ds_2_options = options[:three_ds_2]
          browser_info = three_ds_2_options[:browser_info]
          post[:'3ds_initiate'] = options[:three_ds_initiate] || '01'
          post[:f23] = options[:f23] if options[:f23]
          post[:'3ds_purchasedate'] = Time.now.utc.strftime('%Y%m%d%I%M%S')
          options.dig(:stored_credential, :initiator) == 'merchant' ? post[:'3ds_channel'] = '03' : post[:'3ds_channel'] = '02'
          post[:'3ds_reqchallengeind'] = options[:three_ds_reqchallengeind] if options[:three_ds_reqchallengeind]
          post[:'3ds_redirect_url'] = three_ds_2_options[:notification_url]
          post[:'3ds_challengewindowsize'] = options[:three_ds_challenge_window_size] || '03'
          post[:d5] = browser_info[:user_agent]
          post[:'3ds_transtype'] = options[:three_ds_transtype] || '01'
          post[:'3ds_browsertz'] = browser_info[:timezone]
          post[:'3ds_browserscreenwidth'] = browser_info[:width]
          post[:'3ds_browserscreenheight'] = browser_info[:height]
          post[:'3ds_browsercolordepth'] = browser_info[:depth].to_s == '30' ? '32' : browser_info[:depth]
          post[:d6] = browser_info[:language]
          post[:'3ds_browserjavaenabled'] = browser_info[:java]
          post[:'3ds_browseracceptheader'] = browser_info[:accept_header]
          add_complete_shipping_address(post, options[:shipping_address]) if options[:shipping_address]
        elsif options[:three_d_secure]
          add_normalized_3d_secure_2_data(post, options)
        end
      end

      def add_3d_secure_1_data(post, options)
        if three_d_secure_options = options[:three_d_secure]
          post[:i8] = build_i8(
            three_d_secure_options[:eci],
            three_d_secure_options[:cavv],
            three_d_secure_options[:xid]
          )
          post[:'3ds_version'] = three_d_secure_options[:version]&.start_with?('1') ? '1.0' : three_d_secure_options[:version]
        else
          post[:i8] = build_i8(options[:eci], options[:cavv], options[:xid])
          post[:'3ds_version'] = options[:three_ds_version].nil? || options[:three_ds_version]&.start_with?('1') ? '1.0' : options[:three_ds_version]
        end
      end

      def add_complete_shipping_address(post, shipping_address)
        return if shipping_address.values.any?(&:blank?)

        post[:'3ds_shipaddrstate'] = shipping_address[:state]
        post[:'3ds_shipaddrpostcode'] = shipping_address[:zip]
        post[:'3ds_shipaddrline2'] = shipping_address[:address2]
        post[:'3ds_shipaddrline1'] = shipping_address[:address1]
        post[:'3ds_shipaddrcountry'] = shipping_address[:country]
        post[:'3ds_shipaddrcity'] = shipping_address[:city]
      end

      def add_normalized_3d_secure_2_data(post, options)
        three_d_secure_options = options[:three_d_secure]

        post[:i8] = build_i8(
          three_d_secure_options[:eci],
          three_d_secure_options[:cavv]
        )
        post[:'3ds_version'] = three_d_secure_options[:version] == '2' ? '2.0' : three_d_secure_options[:version]
        post[:'3ds_dstrxid'] = three_d_secure_options[:ds_transaction_id]
      end

      def build_i8(eci, cavv = nil, xid = nil)
        "#{eci}:#{cavv || 'none'}:#{xid || 'none'}"
      end

      def add_echo(post, options)
        # The d2 parameter is used during the certification process
        # See remote tests for full certification test suite
        post[:d2] = options[:echo] unless options[:echo].blank?
      end

      def add_submerchant_id(post, options)
        post[:h3] = options[:submerchant_id] if options[:submerchant_id]
      end

      def add_transaction_type(post, options)
        a9 = options[:zero_dollar_auth] ? '5' : options[:transaction_type]

        post[:a9] = a9 if a9
        post[:a2] = '3' if options.dig(:metadata, :manual_entry)
      end

      def add_processor(post, options)
        post[:r1] = options[:processor] if options[:processor]
        post[:r2] = options[:processor_merchant_id] if options[:processor_merchant_id]
      end

      def add_authorization_details(post, options)
        post[:a10] = options[:authorization_type] if options[:authorization_type]
        post[:a11] = options[:multiple_capture_count] if options[:multiple_capture_count]
      end

      def add_crypto_currency_type(post, options)
        post[:crypto_currency_type] = options[:crypto_currency_type] if options[:crypto_currency_type]
      end

      ACTIONS = {
        purchase: '1',
        authorize: '2',
        capture: '3',
        authorize_void: '4',
        refund: '5',
        credit: '35',
        purchase_void: '7',
        refund_void: '8',
        capture_void: '9',
        threeds_completion: '92',
        referral_cft: '34'
      }

      def commit(action, params, reference_action = nil)
        raw_response = ssl_post(url, post_data(action, params, reference_action))
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: "#{response['Z1']};#{response['Z4']};#{response['A1']};#{action}",
          avs_result: AVSResult.new(code: response['Z9']),
          cvv_result: CVVResult.new(response['Z14']),
          test: test?
        )
      end

      def sign_request(params)
        params = params.sort
        values = params.map do |param|
          value = param[1].gsub(/[<>()\\]/, ' ')
          value.strip
        end
        Digest::MD5.hexdigest(values.join + @options[:cipher_key])
      end

      def sign_request_with_sha256(params)
        sorted_params = sort_parameters(params)
        Digest::SHA256.hexdigest(sorted_params.values.join + @options[:cipher_key])
      end

      def post_data(action, params, reference_action)
        params.keys.each { |key| params[key] = params[key].to_s }
        params[:M] = @options[:merchant_id]
        params[:O] = request_action(action, reference_action)
        params[:K] = @options[:use_sha256_signing] ? sign_request_with_sha256(params) : sign_request(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def request_action(action, reference_action)
        return ACTIONS["#{reference_action}_#{action}".to_sym] if reference_action

        ACTIONS[action]
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        CGI::parse(body).map { |k, v| [k.upcase, v.first] }.to_h
      end

      def success_from(response)
        response['Z2'] == '0'
      end

      def message_from(response)
        if success_from(response)
          'Succeeded'
        else
          RESPONSE_MESSAGES[response['Z6']] || response['Z3'] || 'Unable to read error message'
        end
      end

      def sort_parameters(parameters)
        # Character type lookup hash for faster classification
        char_type_lookup = {}.tap do |lookup|
          ('0'..'9').each { |c| lookup[c] = 0 }  # Digits
          ('A'..'Z').each { |c| lookup[c] = 1 }  # Uppercase letters
          # All other chars default to 2
        end

        # Memoize sort keys to avoid recalculating for the same string
        sort_key_cache = {}
        generate_sort_key = lambda do |str|
          str = str.to_s
          sort_key_cache[str] ||= str.chars.map { |char| [char_type_lookup[char] || 2, char] }
        end

        sanitize_regex = /[<>"'()\\]/

        # Sort keys and build output in one pass
        parameters.keys.
          sort_by(&generate_sort_key).
          each_with_object({}) do |key, sorted_params|
          value = parameters[key]
          sorted_params[key] = value.is_a?(String) ? value.gsub(sanitize_regex, ' ').strip : value
        end
      end
    end
  end
end
