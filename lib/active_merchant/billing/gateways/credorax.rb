module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CredoraxGateway < Gateway
      class_attribute :test_url, :live_na_url, :live_eu_url

      self.display_name = 'Credorax Gateway'
      self.homepage_url = 'https://www.credorax.com/'

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
      self.currencies_without_fractions = %w(BIF CLP DJF GNF JPY KMF KRW PYG RWF VND VUV XAF XOF XPF)
      self.currencies_with_three_decimal_places = %w(BHD IQD JOD KWD LYD OMR TND)

      self.money_format = :cents
      self.supported_cardtypes = %i[visa master maestro]

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
        '34' => 'Suspect Fraud',
        '35' => 'Pick-up, card acceptor contact acquirer',
        '36' => 'Pick up, card restricted',
        '37' => 'Pick up, call acquirer security',
        '38' => 'Pick up, Allowable PIN tries exceeded',
        '39' => 'Transaction Not Allowed',
        '40' => 'Requested function not supported',
        '41' => 'Lost Card, Pickup',
        '42' => 'No universal account',
        '43' => 'Pick up, stolen card',
        '44' => 'No investment account',
        '50' => 'Do not renew',
        '51' => 'Not sufficient funds',
        '52' => 'No checking Account',
        '53' => 'No savings account',
        '54' => 'Expired card',
        '55' => 'Pin incorrect',
        '56' => 'No card record',
        '57' => 'Transaction not allowed for cardholder',
        '58' => 'Transaction not allowed for merchant',
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
        '70' => 'Invalid transaction; contact card issuer',
        '71' => 'Decline PIN not changed',
        '75' => 'Pin tries exceeded',
        '76' => 'Wrong PIN, number of PIN tries exceeded',
        '77' => 'Wrong Reference No.',
        '78' => 'Record Not Found',
        '79' => 'Already reversed',
        '80' => 'Network error',
        '81' => 'Foreign network error / PIN cryptographic error',
        '82' => 'Time out at issuer system',
        '83' => 'Transaction failed',
        '84' => 'Pre-authorization timed out',
        '85' => 'No reason to decline',
        '86' => 'Cannot verify pin',
        '87' => 'Purchase amount only, no cashback allowed',
        '88' => 'MAC sync Error',
        '89' => 'Authentication failure',
        '91' => 'Issuer not available',
        '92' => 'Unable to route at acquirer Module',
        '93' => 'Cannot be completed, violation of law',
        '94' => 'Duplicate Transmission',
        '95' => 'Reconcile error / Auth Not found',
        '96' => 'System malfunction',
        'R0' => 'Stop Payment Order',
        'R1' => 'Revocation of Authorisation Order',
        'R3' => 'Revocation of all Authorisations Order'
      }

      def initialize(options={})
        requires!(options, :merchant_id, :cipher_key)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_email(post, options)
        add_3d_secure(post, options)
        add_3ds_2_optional_fields(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_stored_credential(post, options)
        add_processor(post, options)

        commit(:purchase, post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_email(post, options)
        add_3d_secure(post, options)
        add_3ds_2_optional_fields(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_stored_credential(post, options)
        add_processor(post, options)
        add_authorization_details(post, options)

        commit(:authorize, post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_processor(post, options)

        commit(:capture, post)
      end

      def void(authorization, options={})
        post = {}
        add_customer_data(post, options)
        reference_action = add_reference(post, authorization)
        add_echo(post, options)
        add_submerchant_id(post, options)
        post[:a1] = generate_unique_id
        add_processor(post, options)

        commit(:void, post, reference_action)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_processor(post, options)
        add_email(post, options)

        if options[:referral_cft]
          add_customer_name(post, options)
          commit(:referral_cft, post)
        else
          commit(:refund, post)
        end
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_email(post, options)
        add_echo(post, options)
        add_submerchant_id(post, options)
        add_transaction_type(post, options)
        add_processor(post, options)

        commit(:credit, post)
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

            if key == :'3ds_homephonecountry'
              next unless options[:billing_address] && options[:billing_address][:phone]
            end

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

      def add_payment_method(post, payment_method)
        post[:c1] = payment_method.name
        post[:b2] = CARD_TYPES[payment_method.brand] || ''
        post[:b1] = payment_method.number
        post[:b5] = payment_method.verification_value
        post[:b4] = format(payment_method.year, :two_digits)
        post[:b3] = format(payment_method.month, :two_digits)
      end

      def add_stored_credential(post, options)
        add_transaction_type(post, options)
        # if :transaction_type option is not passed, then check for :stored_credential options
        return unless (stored_credential = options[:stored_credential]) && options.dig(:transaction_type).nil?

        if stored_credential[:initiator] == 'merchant'
          case stored_credential[:reason_type]
          when 'recurring'
            stored_credential[:initial_transaction] ? post[:a9] = '1' : post[:a9] = '2'
          when 'installment', 'unscheduled'
            post[:a9] = '8'
          end
        else
          post[:a9] = '9'
        end
      end

      def add_customer_data(post, options)
        post[:d1] = options[:ip] || '127.0.0.1'
        if (billing_address = options[:billing_address])
          post[:c5]   = billing_address[:address1]  if billing_address[:address1]
          post[:c7]   = billing_address[:city]      if billing_address[:city]
          post[:c10]  = billing_address[:zip]       if billing_address[:zip]
          post[:c8]   = billing_address[:state]     if billing_address[:state]
          post[:c9]   = billing_address[:country]   if billing_address[:country]
          post[:c2]   = billing_address[:phone]     if billing_address[:phone]
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

      def add_customer_name(post, options)
        post[:j5] = options[:first_name] if options[:first_name]
        post[:j13] = options[:last_name] if options[:last_name]
      end

      def add_3d_secure(post, options)
        if options[:eci] && options[:xid]
          add_3d_secure_1_data(post, options)
        elsif options[:execute_threed] && options[:three_ds_2]
          three_ds_2_options = options[:three_ds_2]
          browser_info = three_ds_2_options[:browser_info]
          post[:'3ds_initiate'] = options[:three_ds_initiate] || '01'
          post[:'3ds_purchasedate'] = Time.now.utc.strftime('%Y%m%d%I%M%S')
          options.dig(:stored_credential, :initiator) == 'merchant' ? post[:'3ds_channel'] = '03' : post[:'3ds_channel'] = '02'
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
          if (shipping_address = options[:shipping_address])
            post[:'3ds_shipaddrstate'] = shipping_address[:state]
            post[:'3ds_shipaddrpostcode'] = shipping_address[:zip]
            post[:'3ds_shipaddrline2'] = shipping_address[:address2]
            post[:'3ds_shipaddrline1'] = shipping_address[:address1]
            post[:'3ds_shipaddrcountry'] = shipping_address[:country]
            post[:'3ds_shipaddrcity'] = shipping_address[:city]
          end
        elsif options[:three_d_secure]
          add_normalized_3d_secure_2_data(post, options)
        end
      end

      def add_3d_secure_1_data(post, options)
        post[:i8] = build_i8(options[:eci], options[:cavv], options[:xid])
        post[:'3ds_version'] = options[:three_ds_version].nil? || options[:three_ds_version] == '1' ? '1.0' : options[:three_ds_version]
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

      def build_i8(eci, cavv=nil, xid=nil)
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
        post[:a9] = options[:transaction_type] if options[:transaction_type]
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

      ACTIONS = {
        purchase: '1',
        authorize: '2',
        capture: '3',
        authorize_void: '4',
        refund: '5',
        credit: '6',
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

      def post_data(action, params, reference_action)
        params.keys.each { |key| params[key] = params[key].to_s }
        params[:M] = @options[:merchant_id]
        params[:O] = request_action(action, reference_action)
        params[:K] = sign_request(params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def request_action(action, reference_action)
        if reference_action
          ACTIONS["#{reference_action}_#{action}".to_sym]
        else
          ACTIONS[action]
        end
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        Hash[CGI::parse(body).map { |k, v| [k.upcase, v.first] }]
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
    end
  end
end
