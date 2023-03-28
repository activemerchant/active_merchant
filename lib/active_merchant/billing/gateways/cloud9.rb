# frozen-string-literal: true

module ActiveMerchant #:nodoc: ALL
  module Billing
    # === Cloud 9 payment gateway.
    #
    class Cloud9Gateway < Gateway
      self.test_url = 'https://testlinkmytime.c9pg.com:11911'
      self.live_url = 'https://linkmytime.c9pg.com:11911'
      self.default_currency = 'USD'
      self.display_name = 'Cloud9 Payment Gateway'
      self.homepage_url = 'http://cloud9paymentgateway.com'
      self.money_format = :cents
      self.supported_countries = %w[CA US]
      self.supported_cardtypes = %i[visa master american_express jcb discover]

      CARD_TYPE_MAPPING        = {
        'Visa'             => 'Visa',
        'VISA'             => 'Visa',
        'Master'           => 'Mastercard',
        'Mastercard'       => 'Mastercard',
        'MasterCard'       => 'Mastercard',
        'Master Card'      => 'Mastercard',
        'Discover'         => 'Discover',
        'American Express' => 'American Express',
        'Amex'             => 'American Express',
        'DinersClub'       => 'Diners Club',
        'Diners Club'      => 'Diners Club',
        'JCB'              => 'JCB',
      }.freeze

      # TRANSACTION_TYPES = [AUTHORIZE, PURCHASE, CAPTURE, ADD_TIP, VOID, REFUND, INQUIRY, MODIFY, BATCH]
      AUTHORIZE = 'Auth'
      PURCHASE = 'Sale'
      CAPTURE = 'Finalize'
      ADD_TIP = 'Addtip'
      VOID = 'Void'
      REVERSE = 'Reverse'
      REFUND = 'Refund'
      ADJUST = 'Adjust'
      INQUIRY = 'Inquiry'
      MODIFY = 'Modify'
      BATCH = 'Batch'
      CREATE_TOKEN = 'CreateCardToken'

      TAX_INDICATORS = %w[Ntprvd Prvded NonTax].freeze
      FUNDING_CREDIT = 'Credit'
      FUNDING_TYPES = [FUNDING_CREDIT, 'Debit', 'EBT Food', 'EBT Cash', 'Prepaid', 'Gift'].freeze
      ENCRYPT_TARGETS = %w[Track1 Track2 PAN].freeze

      STATUS_CANCEL = 'cancel'
      STATUS_FAIL = 'fail'
      STATUS_INVALID = 'invalidData'
      STATUS_SUCCESS = 'success'
      STATUS_TIMEOUT = 'timeout'

      ENTRY_SWIPE = 'Swipe'
      ENTRY_MANUAL = 'Manual'
      ENTRY_PROXIMITY = 'Proximity'
      ENTRY_CONTACT = 'ChipContact'
      ENTRY_CONTACTLESS = 'ChipContactless'
      ENTRY_EMV_FB_SWP = 'EMVFallback2Swip'

      STANDARD_ERROR_CODE_MAPPING = {
        '001' => STANDARD_ERROR_CODE[:call_issuer], # Refer to issuer
        '002' => STANDARD_ERROR_CODE[:call_issuer], # Refer to issuer-Special condition
        '003' => STANDARD_ERROR_CODE[:config_error], # Invalid Merchant ID
        '004' => STANDARD_ERROR_CODE[:pick_up_card], # Pick up card (no fraud)
        '005' => STANDARD_ERROR_CODE[:card_declined], # do not honour
        '006' => STANDARD_ERROR_CODE[:card_declined], # Error response text from check service
        '007' => STANDARD_ERROR_CODE[:pick_up_card], # pick up card (fraud account)
        # '008' => STANDARD_ERROR_CODE[:approved],
        # '010' => STANDARD_ERROR_CODE[:partial_approval],
        # '011' => STANDARD_ERROR_CODE[:vip_approval],
        '012' => STANDARD_ERROR_CODE[:config_error], # invalid transaction
        '013' => STANDARD_ERROR_CODE[:invalid_number], # invalid amount
        '014' => STANDARD_ERROR_CODE[:invalid_number], # invalid card number
        '015' => STANDARD_ERROR_CODE[:config_error], # no such issuer
        '019' => STANDARD_ERROR_CODE[:processing_error], # Re-enter transaction
        '021' => STANDARD_ERROR_CODE[:processing_error], # Unable to back out transaction
        '028' => STANDARD_ERROR_CODE[:processing_error], # File is temporarily unavailable
        '034' => STANDARD_ERROR_CODE[:unsupported_feature], # transaction cancelled - mastercard use only
        '051' => STANDARD_ERROR_CODE[:card_declined], # insufficient funds
        '054' => STANDARD_ERROR_CODE[:expired_card], # expired card
        '055' => STANDARD_ERROR_CODE[:incorrect_pin], # incorrect pin
        '057' => STANDARD_ERROR_CODE[:config_error], # transaction not permitted - card
        '058' => STANDARD_ERROR_CODE[:config_error], # transaction not permitted - terminal
        '059' => STANDARD_ERROR_CODE[:config_error], # transaction not permitted - merchant
        '062' => STANDARD_ERROR_CODE[:card_declined], # invalid service code - restricted
        '075' => STANDARD_ERROR_CODE[:card_declined], # pin retries exceeded
        '076' => STANDARD_ERROR_CODE[:processing_error], # Unable to locate, no match
        '078' => STANDARD_ERROR_CODE[:config_error], # no account
        '079' => STANDARD_ERROR_CODE[:config_error], # Already reversed at switch
        '081' => STANDARD_ERROR_CODE[:processing_error], # Cryptographic error
        '082' => STANDARD_ERROR_CODE[:incorrect_cvc], # CVV data not correct
        '083' => STANDARD_ERROR_CODE[:incorrect_pin], # cannot verify pin
        # '085' => STANDARD_ERROR_CODE[:card_ok],          # no reason to decline
        '091' => STANDARD_ERROR_CODE[:processing_error], # no reply Issuer or switch is unavailable
        '092' => STANDARD_ERROR_CODE[:processing_error], # Destination not found
        '093' => STANDARD_ERROR_CODE[:processing_error], # Violation, cannot complete
        '094' => STANDARD_ERROR_CODE[:processing_error], # Unable to locate, no match
        '096' => STANDARD_ERROR_CODE[:processing_error], # System malfunction
        '0FF' => STANDARD_ERROR_CODE[:processing_error], # Network error
        '101' => STANDARD_ERROR_CODE[:config_error], # Invalid GMID
        '102' => STANDARD_ERROR_CODE[:config_error], # Invalid GTID
        '103' => STANDARD_ERROR_CODE[:config_error], # Invalid GMPW
        '104' => STANDARD_ERROR_CODE[:invalid_number], # Invalid GTRC
        '105' => STANDARD_ERROR_CODE[:invalid_number], # Invalid Card Token
        '106' => STANDARD_ERROR_CODE[:config_error], # Invalid Database
        '107' => STANDARD_ERROR_CODE[:processing_error], # Processor does not support card type
        '108' => STANDARD_ERROR_CODE[:processing_error], # Processor not supported or not loaded to system
        '109' => STANDARD_ERROR_CODE[:invalid_number], # Invalid amount
        '110' => STANDARD_ERROR_CODE[:processing_error], # Void amount exceeds original authorized amount
        '111' => STANDARD_ERROR_CODE[:config_error], # Offline transaction can only be used for Credit/EBT Footstamp's sale
        '112' => STANDARD_ERROR_CODE[:config_error], # Credit/EBT Foodstamp card with cashback is not allowed
        '113' => STANDARD_ERROR_CODE[:processing_error], # Addtip must be based on Auth/Sale transaction
        '114' => STANDARD_ERROR_CODE[:processing_error], # Finalize must be based on Auth transaction
        '115' => STANDARD_ERROR_CODE[:processing_error], # Original transaction has already been voided
        '116' => STANDARD_ERROR_CODE[:processing_error], # Offline transaction must supply AuthCode
        '117' => STANDARD_ERROR_CODE[:processing_error], # Engine process transaction time out
        '118' => STANDARD_ERROR_CODE[:processing_error], # Proxy process message time out
        '119' => STANDARD_ERROR_CODE[:processing_error], # PDC process transaction time out
        '120' => STANDARD_ERROR_CODE[:processing_error], # Processor process transaction time out
        '999' => STANDARD_ERROR_CODE[:processing_error], # Processor no response code, Please refer response text
      }

      # This gateway requires that a valid username and password be passed in the +options+ hash.
      #
      # === Required Options
      # * <tt>:merchant_id</tt>
      # * <tt>:terminal_id</tt>
      # * <tt>:password</tt>
      # === Optional Options
      # * <tt>test</tt> -- determines which server to connect to
      def initialize(options = {})
        super
      end

      # A Sale transaction authorizes a sale purchased. This action decreases the cardholder's limit to buy.
      # It authorizes a transfer of funds from the cardholder's account to merchant's account.
      #
      # * <tt>amount</tt> -- the requested purchase amount
      # * <tt>payment</tt> -- payment source, can be either a CreditCard or token.
      # * <tt>options</tt> -- options to be passed to the processor
      def purchase(amount, payment, options = {})
        post = {}
        add_configure_group(post, options)
        add_request_amount_group(post, options, amount)
        add_action_group(post, options, payment)
        add_request_extend_info_group(post, options)
        add_trace_group(post, options)
        add_request_card_info_group(post, payment, options)
        add_encryption_data_group(post, options)
        add_pin_group(post, payment)

        commit(PURCHASE, 'restApi', post)
      end

      # An Authorize transaction places a temporary hold on the customers account. Approvals on authorizations are
      # used later to transfer funds by Finalize or AddTip.
      #
      # * <tt>amount</tt> -- the requested purchase amount
      # * <tt>payment</tt> -- payment source, can be either a CreditCard or token.
      # * <tt>options</tt> -- options to be passed to the processor
      def authorize(amount, payment, options = {})
        post = {}
        add_configure_group(post, options)
        add_request_amount_group(post, options, amount)
        add_action_group(post, options, payment)
        add_request_extend_info_group(post, options)
        add_trace_group(post, options)
        add_request_card_info_group(post, payment, options)
        add_encryption_data_group(post, options)
        add_pin_group(post, payment)

        commit(AUTHORIZE, 'restApi', post)
      end

      # Capture is used to finalize a previously authorized transaction. A Finalize transaction is used to change an
      # Authorize transaction to sale transaction without modification. A Modify transaction is used to alter the
      # transaction amount of an original transaction, Authorize or Sale. If the original transaction is Authorize, this
      # operation transfers the Auth to Sale.
      #
      # * <tt>amount</tt> -- the requested purchase amount
      # * <tt>authorization</tt> -- the gateway trace number obtained from a previous Authorize transaction.
      # * <tt>options</tt> -- options to be passed to the processor
      def capture(amount, authorization, options = {})
        modify = options[:amount].present?

        post = {}
        add_configure_group(post, options)
        add_request_amount_group(post, options, amount) if modify
        add_action_group(post, options)
        add_trace_group(post, options, authorization)

        if modify
          MultiResponse.run do |r|
            r.process { commit(MODIFY, 'restApi', post) }
            return r.primary_response unless r.primary_response.success?
            r.process { commit(CAPTURE, 'restApi', post.except(:MainAmt)) }
          end.responses.last
        else
          commit(CAPTURE, 'restApi', post)
        end
      end

      def refund(amount, authorization, options = {})
        auth_amount = options[:authorized_amount].to_i
        amount    ||= auth_amount # if no amount passed, assume full refund
        amount      = auth_amount - amount
        void        = amount == 0

        post = {}
        add_configure_group(post, options, password_required: true)
        add_request_amount_group(post, options, void ? nil : amount)
        add_trace_group(post, options, authorization)
        add_custom_group(post, void)
        commit(void ? REVERSE : ADJUST, 'restApi', post)
      end

      # A Credit transaction is used to authorize a refund to a customer's credit card account without reference to a
      # prior authorization. In Cloud9 this is called a Refund.
      #
      # * <tt>amount</tt> -- the amount to be credited to the +payment+ account
      # * <tt>payment</tt> -- payment source, can be either a CreditCard or token.
      # * <tt>options</tt> -- options to be passed to the processor
      def credit(amount, payment, options = {})
        post = {}
        add_configure_group(post, options, password_required: true)
        add_request_amount_group(post, options, amount)
        add_action_group(post, options, payment)
        add_trace_group(post, options, authorization)
        add_request_card_info_group(post, payment, options)
        commit(REFUND, 'restApi', post)
      end

      # A Void transaction is used to cancel an authorized or captured transaction. We use the REVERSE API call here
      # since that is agnostic to whether the transaction has been batched or not.
      #
      # * <tt>authorization</tt> -- the gateway trace number for a previous Authorize to be voided.
      # * <tt>options</tt> -- options to be passed to the processor
      def void(authorization, options = {})
        post = {}
        add_configure_group(post, options, password_required: true)
        add_trace_group(post, options, authorization)
        add_request_extend_info_group(post, options)
        add_custom_group(post)
        commit(REVERSE, 'restApi', post)
      end

      # Store requests token information for a card or token.
      #
      # * <tt>card</tt> -- either a CreditCard or token.
      # from {Response#authorization}.
      def store(card, options = {})
        post = {}
        add_configure_group(post, options)
        add_action_group(post, options, card)
        add_request_card_info_group(post, card, options)

        response = commit(CREATE_TOKEN, 'restApi', post)
        return response unless response.success?

        Response.new(
          true,
          response.message,
          card_attributes(response).as_json,
          test: test?,
          authorization: response.authorization,
          avs_result:    response.avs_result,
          cvv_result:    response.cvv_result[:code],
        )
      end

      private

      # Add the Configure Group of options - used for ALL transactions
      #
      # == Options
      # * <tt>:chain_id</tt> -- optional
      # * <tt>:merchant_id</tt> -- required
      # * <tt>:terminal_id</tt> -- required if +terminal_id_required+
      # * <tt>:password</tt> -- required if +password_required+
      # * <tt>:allow_partial_auth</tt> -- allow partial authorization if full amount is not available; defaults +false+
      # == Flags
      # * <tt>:password_required</tt> -- optional, defaults to false (only needed for refunds)
      # * <tt>:terminal_id_required</tt> -- optional, defaults to true
      #
      def add_configure_group(post, options, password_required: false, terminal_id_required: true)
        if @options[:chain_id].present?
          post[:GCID] = @options[:chain_id]
        else
          if terminal_id_required
            requires!(@options, :merchant_id, :terminal_id)
          else
            requires!(@options, :merchant_id)
          end

          post[:GMID] = @options[:merchant_id]
          optional_assign(post, :GTID, @options[:terminal_id]) if terminal_id_required
          optional_assign(post, :GMPW, @options[:password]) if password_required
        end
        optional_assign(post, :AllowsPartialAuth, options[:allow_partial_auth])
      end

      # Add the Request Amount Group of options - only used for authorize, purchase, refund, & add_tip
      #
      # * <tt>money</tt> -- optional
      # ==== Options
      # * <tt>:tip_amount</tt> -- tip that is in addition to +money+, optional
      # * <tt>:tax_amount</tt> -- tax amount included with +money+, optional
      # * <tt>:cash_back_amount</tt> -- cash back amount included with +money+, optional
      # * <tt>:tax_indicator</tt> -- additional info on tax amount, optional, defaults +Prvded+
      def add_request_amount_group(post, options, money = nil)
        post[:MainAmt] = amount(money) if money.present?
        post[:TipAmt] = amount(options[:tip_amount]) if options[:tip_amount].present?
        post[:IncTaxAmt] = amount(options[:tax_amount]) if options[:tax_amount].present?
        post[:IncCashBackAmt] = amount(options[:cash_back_amount]) if options[:cash_back_amount].present?
        post[:TaxIndicator] = options[:tax_indicator] if TAX_INDICATORS.include?(options[:tax_indicator])
      end

      # Add the Action Group of options - used for ALL transactions
      #
      # ==== Options
      # * <tt>:offline</tt> -- offline transaction, Y/N, required, defaults to +N+
      def add_action_group(post, options, payment = nil)
        post[:IsOffline] = %w[Y N].include?(options[:offline]) ? options[:offline] : 'N'
        post[:VerifyCard] = 'N' if card_token?(payment) # don't need verification for tokens
        post[:CheckDuplicate] = 'Y' if options[:check_duplicate] || true
      end

      # Add the Request Extend Group of options
      #
      # ==== Options
      # * <tt>:invoice_num</tt> -- invoice number, optional
      # * <tt>:order_num</tt> -- only used for purchase card (??), optional
      # * <tt>:authorization_code</tt> -- only used for offline transactions, optional
      # * <tt>:voucher_serial_number</tt> -- only used for offline EBT transaction, optional
      # * <tt>:additional_info</tt> -- reserved for future use. data is delimited by a FS (0x1c) and is formatted as
      #                                follows: Key=Value0x1cKey=Value0x1cKey=Value, optional
      # * <tt>:print_receipt</tt> -- used to ask for a printed receipt if the terminal supports it, defaults to 'N'
      def add_request_extend_info_group(post, options)
        optional_assign(post, :InvoiceNum, options[:invoice_num])
        optional_assign(post, :OrderNum, options[:order_num])
        optional_assign(post, :AuthCode, options[:authorization_code])
        optional_assign(post, :VoucherNum, options[:voucher_serial_number])
        optional_assign(post, :AdditionalInfo, options[:additional_info])
        optional_assign(post, :NeedReceipt, options[:need_receipt])
      end

      # Add the Trace Group of options - used for ALL transactions
      #
      # * <tt>authorization</tt> -- a unique trace number assigned to a transaction by Cloud9 payment and returned in
      #                             the response message. The POS must submit it back for Void / Addtip / Finalize etc
      #                             based previous transactions.
      # ==== Options
      # * <tt>:source_trace_num</tt> -- source trace number provided by the merchant and it uniquely identifies a
      # * transaction, required
      def add_trace_group(post, options, authorization = nil)
        # requires!(options, :source_trace_num)
        # post[:SourceTraceNum] = options[:source_trace_num]
        optional_assign(post, :SourceTraceNum, options[:source_trace_num])
        post[:GTRC] = authorization if authorization.present?
      end

      # Add the Request Card Info Group of options - used when card info is from POS, not PDC. and the item,
      # NeedSwipCard, must be N.
      #
      # ==== Options
      def add_request_card_info_group(post, payment, options)
        add_credit_card(post, payment, options)
        post[:CommercialCard] = options[:commercial_card].present? && options[:commercial_card] ? 'Y' : 'N'
      end

      # Extract request card info from credit_card parameter. This could be an AM CreditCard object, with either track
      # data, or manually entered card info. It can also be a token from a previously saved card. If ommitted (nil),
      # the NeedSwipCard parameter is set to request card swipe from an attached terminal.
      def add_credit_card(post, credit_card, options = {})
        post[:NeedSwipCard] = 'N'
        if credit_card.respond_to?(:number)
          if credit_card.respond_to?(:track_data) && credit_card.track_data.present?
            post[:Track2] = credit_card.track_data
            post[:EntryMode] = ENTRY_SWIPE
          else
            post[:AccountNum] = credit_card.number
            post[:ExpDate] = if credit_card.month.present? && credit_card.year.present?
                               (credit_card.month + 100).to_s[1..2] + credit_card.year.to_s[-2..-1]
                             end
            post[:CVVNum] = credit_card.verification_value if credit_card.verification_value?
            post[:CustomerName] = credit_card.name if credit_card.name.present?
            post[:CustomerZipCode] = options[:address][:zip] if options.dig(:address, :zip).present?
            post[:CustomerAddress] = options[:address][:address1] if options.dig(:address, :address1).present?
            post[:CardPresent] = credit_card.manual_entry || false ? 'N' : 'Y'
            post[:EntryMode] = ENTRY_MANUAL
          end
          post[:Medium] = FUNDING_TYPES.include?(options[:funding]) ? options[:funding] : FUNDING_CREDIT
        elsif card_token?(credit_card)
          post[:CardToken] = credit_card
          post[:Medium] = FUNDING_CREDIT
          post[:EntryMode] = ENTRY_MANUAL
        elsif credit_card.blank?
          post[:NeedSwipCard] = 'Y'
        end
        post[:RequestCardToken] = 'Y'
      end

      def add_pin_group(post, credit_card)
        if credit_card.respond_to?(:encrypted_pin_cryptogram) &&
          credit_card.encrypted_pin_cryptogram.present? &&
          credit_card.encrypted_pin_ksn.present?
          post[:PinBlock] = credit_card.encrypted_pin_cryptogram
          post[:KSN] = credit_card.encrypted_pin_ksn
        end
      end

      # Add the Encryption Data Group of options - used when card info is from POS, not PDC. and the item, NeedSwipCard,
      # must be N.
      #
      # ==== Options
      # * <tt>:encryption_key_id</tt> -- used to retrieve the private key, which is required for decryption
      # * <tt>:encryption_target</tt> -- type of data that is being encrypted
      # * <tt>:encrypted_block</tt> -- track data or card number provided in an encrypted block. be Present when card
      # * data is encrypted
      def add_encryption_data_group(post, options)
        requires!(options, [:encryption_target] + ENCRYPT_TARGETS, :encryption_key_id) if options[:encrypted_block].present?
        optional_assign(post, :KeyID, options[:encryption_key_id])
        optional_assign(post, :EncrtTrgt, options[:encryption_target])
        optional_assign(post, :EncrptBlock, options[:encrypted_block])
      end

      # Add the Custom Group of options - used for now to set CreditOnFailure to circumvent rejects from TSYS for voids.
      #
      # <tt>void</tt> -- set to true if command would be VOID
      def add_custom_group(post, void = true)
        post[:CreditOnFailure] = 'Y' if void
      end

      def card_attributes(response)
        response.params['Brand'] = CARD_TYPE_MAPPING[response.params['Brand']]
        response.params['ExpDate'] = response.params['ExpDate'].rjust(4, '0')
        {
          token:     response.params['CardToken'],
          last4:     response.params.dig('AccountNum')[-4..-1],
          brand:     response.params['Brand'],
          funding:   response.params['Medium'].downcase,
          exp_month: response.params['ExpDate'][0..1],
          exp_year:  '20' + response.params['ExpDate'][2..3]
        }
      end

      def error_code_from(response)
        code = response['ErrorCode'] || response['ResponseCode'] # Cloud9 errors take precedence over TSYS
        STANDARD_ERROR_CODE_MAPPING[code] || STANDARD_ERROR_CODE[:processing_error]
      end

      def error_message_from(response)
        response['ErrorText'] || response['ResponseText'] # Cloud9 errors take precedence over TSYS
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def connection_error(e)
        {
          'Status' => STATUS_FAIL,
          'ErrorCode' => '0FF', # Network error
          'ErrorText' => e.message
        }
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Cloud9 API.'
        msg + "  (The raw response returned by the API was: #{raw_response.inspect})"
        {
          'Status' => STATUS_FAIL,
          'ErrorCode' => '096', # System malfunction
          'ErrorText' => msg
        }
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def api_request(action, endpoint, parameters = nil)
        raw_response = nil
        begin
          raw_response = ssl_post(target_url(endpoint, parameters[:GMID]), post_data(action, parameters), headers(parameters))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        rescue ActiveMerchant::ConnectionError => e
          response = connection_error(e)
        end
        response
      end

      def authorization_from(action, response)
        case action
        when CREATE_TOKEN
          response['CardToken']
        else
          response['GTRC']
        end
      end

      def commit(action, endpoint, parameters, options = {})
        response = api_request(action, endpoint, parameters)

        success = response['Status'] == STATUS_SUCCESS

        Response.new(
          success,
          success ? 'Transaction approved' : error_message_from(response),
          response,
          test: test?,
          authorization: authorization_from(action, response),
          avs_result: { code: response['AVSResultCode'] },
          cvv_result: response['CVVResultCode'],
          emv_authorization: nil,
          error_code: success ? nil : error_code_from(response)
        )
      end

      def headers(_options = {})
        {
          'Content-Type': 'application/json',
          'User-Agent': "Cloud9/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
        }
      end

      def message_from(response)
        MESSAGES.fetch(response['response_code'].to_i, false) || response['message']
      end

      def optional_assign(target, key, source)
        target[key] = source if source.present?
      end

      def post_data(action, parameters = {})
        post = { TransType: action }

        JSON.generate(post.merge(parameters))
      end

      def requires!(hash, *params)
        hash.select! { |_key, value| value.present? } # discard any nil entries
        super
      end

      def target_url(endpoint, gmid)
        url = test? ? self.test_url : self.live_url
        endpoint = '/' + endpoint if endpoint&.size&.positive?
        query_string = gmid.present? ? "?GMID=#{gmid}" : ''
        url + endpoint + query_string
      end

      def card_token?(payment)
        payment.is_a?(String)
      end
    end
  end
end
