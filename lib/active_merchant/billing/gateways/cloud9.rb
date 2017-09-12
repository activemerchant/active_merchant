module ActiveMerchant #:nodoc: ALL
  module Billing
    # === Cloud 9 payment gateway.
    #
    class Cloud9Gateway < Gateway
      self.test_url             = 'https://testlink.c9pg.com:5568/restApi'
      self.live_url             = 'TBD'
      self.default_currency     = 'USD'
      self.display_name         = 'Cloud9 Payment Gateway'
      self.homepage_url         = 'http://cloud9paymentgateway.com'
      self.money_format         = :cents
      self.supported_countries  = %w[CA US]
      self.supported_cardtypes  = %i[visa master american_express jcb discover]

      # TRANSACTION_TYPES = [AUTHORIZE, PURCHASE, CAPTURE, ADD_TIP, VOID, REFUND, INQUIRY, MODIFY, BATCH].freeze
      AUTHORIZE         = 'Auth'.freeze
      PURCHASE          = 'Sale'.freeze
      CAPTURE           = 'Finalize'.freeze
      ADD_TIP           = 'Addtip'.freeze
      VOID              = 'Void'.freeze
      REFUND            = 'Refund'.freeze
      INQUIRY           = 'Inquiry'.freeze
      MODIFY            = 'Modify'.freeze
      BATCH             = 'Batch'.freeze

      TAX_INDICATORS    = %w[Ntprvd Prvded NonTax].freeze
      FUNDING_CREDIT    = 'Credit'.freeze
      FUNDING_TYPES     = [FUNDING_CREDIT, 'Debit', 'EBT Food', 'EBT Cash', 'Prepaid', 'Gift'].freeze
      ENCRYPT_TARGETS   = %w[Track1 Track2 PAN].freeze

      STATUS_CANCEL     = 'cancel'.freeze
      STATUS_FAIL       = 'fail'.freeze
      STATUS_INVALID    = 'invalidData'.freeze
      STATUS_SUCCESS    = 'success'.freeze
      STATUS_TIMEOUT    = 'timeout'.freeze

      # TODO: PMTSVC this is from Stripe, still to get error codes from Cloud9
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
        'test_mode_live_card' => STANDARD_ERROR_CODE[:test_mode_live_card]
      }.freeze

      # This gateway requires that a valid username and password be passed in the +options+ hash.
      #
      # === Required Options
      # * <tt>:merchant_id</tt>
      # * <tt>:terminal_id</tt>
      # * <tt>:password</tt>
      # === Optional Options
      # * <tt>test</tt> -- determines which server to connect to
      def initialize(options = {})
        requires!(options, :merchant_id, :password, :terminal_id)
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
        add_action_group(post, options)
        add_request_extend_info_group(post, options)
        add_trace_group(post, options)
        add_request_card_info_group(post, payment, options)
        add_encryption_data_group(post, options)
        add_pin_group(post, payment)

        commit(PURCHASE, post)
      end

      # An Authorize transaction places a temporary hold on the customer’s account. Approvals on authorizations are
      # used later to transfer funds by Finalize or AddTip.
      #
      # * <tt>amount</tt> -- the requested purchase amount
      # * <tt>payment</tt> -- payment source, can be either a CreditCard or token.
      # * <tt>options</tt> -- options to be passed to the processor
      def authorize(amount, payment, options = {})
        post = {}
        add_configure_group(post, options)
        add_request_amount_group(post, options, amount)
        add_action_group(post, options)
        add_request_extend_info_group(post, options)
        add_trace_group(post, options)
        add_request_card_info_group(post, payment, options)
        add_encryption_data_group(post, options)
        add_pin_group(post, payment)

        commit(AUTHORIZE, post)
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
        modify = options['MainAmt'].present?

        post = {}
        add_configure_group(post, options)
        if modify
          add_request_amount_group(post, options, amount)
        end
        add_action_group(post, options)
        add_trace_group(post, options, authorization)

        commit(modify ? MODIFY : CAPTURE, post)
      end

      # TODO: PMTSVC -- waiting for Cloud9 feedback
      def refund(money, identification)
        post = {}
        add_configure_group(post, options)
        commit('refund', post)
      end

      # A Credit transaction is used to authorize a refund to a customer's credit card account without reference to a
      # prior authorization. In Cloud9 this is called a Refund.
      #
      # * <tt>amount</tt> -- the amount to be credited to the +payment+ account
      # * <tt>payment</tt> -- payment source, can be either a CreditCard or token.
      # * <tt>options</tt> -- options to be passed to the processor
      def credit(amount, payment, options = {})
        post = {}
        add_configure_group(post, options)
        add_request_amount_group(post, options, amount)
        add_trace_group(post, options, authorization)
        add_request_card_info_group(post, payment, options)
        commit(REFUND, post)
      end

      # A Void transaction is used to cancel an authorized transaction before it has been settled.
      #
      # * <tt>authorization</tt> -- the gateway trace number for a previous Authorize to be voided.
      # * <tt>options</tt> -- options to be passed to the processor
      def void(authorization, options = {})
        post = {}
        add_configure_group(post, options)
        add_trace_group(post, options, authorization)
        add_request_extend_info_group(post, options)
        commit(VOID, post)
      end

      # Cloud9 doesn't have a pure tokenizing function at the moment. So what we do here, is to make an Authorize call
      # with a small amount, and requesting a token to be returned.
      #
      # * <tt>payment</tt> -- payment source, can be either a CreditCard or token.
      # from {Response#authorization}.
      def store(payment, options = {})
        response = authorize(100, payment, options)
        response.authorization = response.params['CardToken'] if response.success
      end

      private

      # Add the Configure Group of options - used for ALL transactions
      #
      # ==== Options
      # * <tt>:merchant_id</tt> -- required
      # * <tt>:terminal_id</tt> -- required
      # * <tt>:password</tt> -- required
      # * <tt>:allow_partial_auth</tt> -- allow partial authorization if full amount is not available; defaults +false+
      def add_configure_group(post, options)
        post[:GMID] = options[:merchant_id]
        post[:GTID] = options[:terminal_id]
        post[:GMPW] = options[:password]
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
        post[:MainAmt]        = amount(money) if money.present?
        post[:TipAmt]         = amount(options[:tip_amount]) if options[:tip_amount].present?
        post[:IncTaxAmt]      = amount(options[:tax_amount]) if options[:tax_amount].present?
        post[:IncCashBackAmt] = amount(options[:cash_back_amount]) if options[:cash_back_amount].present?
        post[:TaxIndicator]   = options[:tax_indicator] if TAX_INDICATORS.include?(options[:tax_indicator])
      end

      # Add the Action Group of options - used for ALL transactions
      #
      # ==== Options
      # * <tt>:offline</tt> -- offline transaction, Y/N, required, defaults to +N+
      def add_action_group(post, options)
        post[:IsOffline] = %w[Y N].include?(options[:offline]) ? options[:offline] : 'N'
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
      def add_request_extend_info_group(post, options)
        optional_assign(post, :InvoiceNum, options[:invoice_num])
        optional_assign(post, :OrderNum, options[:order_num])
        optional_assign(post, :AuthCode, options[:authorization_code])
        optional_assign(post, :VoucherNum, options[:voucher_serial_number])
        optional_assign(post, :AdditionalInfo, options[:additional_info])
      end

      # Add the Trace Group of options - used for ALL transactions
      #
      # * <tt>authorization</tt> -- a unique trace number assigned to a transaction by Cloud9 payment and returned in
      #                             the response message. The POS must submit it back for Void / Addtip / Finalize etc
      #                             based previous transactions.
      # ==== Options
      # * <tt>:source_trace_num</tt> -- source trace number provided by the merchant and it uniquely identifies a transaction, required
      def add_trace_group(post, options, authorization = nil)
        requires!(options, :source_trace_num)
        post[:SourceTraceNum] = options[:source_trace_num]
        post[:GTRC]           = authorization if authorization.present?
      end

      # Add the Request Card Info Group of options - used when card info is from POS, not PDC. and the item,
      # NeedSwipeCard, must be “N”.
      #
      # ==== Options
      def add_request_card_info_group(post, payment, options)
        add_credit_card(post, payment, options)
        post[:CommercialCard] = options[:commercial_card].present? && options[:commercial_card] ? 'Y' : 'N'
      end

      # Extract request card info from credit_card parameter. This could be an AM CreditCard object, with either track
      # data, or manually entered card info. It can also be a token from a previously saved card. If ommitted (nil),
      # the NeedSwipeCard parameter is set to request card swipe from an attached terminal.
      def add_credit_card(post, credit_card, options = {})
        if credit_card.respond_to?(:number)
          if credit_card.respond_to?(:track_data) && credit_card.track_data.present?
            post[:Track2] = credit_card.track_data
          else
            post[:AccountNum]       = credit_card.number
            post[:ExpDate]          = credit_card.month.to_s + credit_card.year.to_s[-2..-1]
            post[:CVVNum]           = credit_card.verification_value if credit_card.verification_value?
            post[:CardPresent]      = credit_card.manual_entry || false ? 'N' : 'Y'
          end
          post[:Medium]           = FUNDING_TYPES.include?(options[:funding]) ? options[:funding] : FUNDING_CREDIT
          post[:RequestCardToken] = 'Y'
        elsif credit_card.kind_of?(String)
          post[:CardToken] = credit_card
        elsif credit_card.blank?
          post[:NeedSwipeCard]    = 'Y'
          post[:RequestCardToken] = 'Y'
        end
      end

      def add_pin_group(post, credit_card)
        if credit_card.respond_to?(:encrypted_pin_cryptogram) &&
           credit_card.encrypted_pin_cryptogram.present? &&
           credit_card.encrypted_pin_ksn.present?
          post[:PinBlock] = credit_card.encrypted_pin_cryptogram
          post[:KSN]      = credit_card.encrypted_pin_ksn
        end
      end

      # Add the Encryption Data Group of options - used when card info is from POS, not PDC. and the item, NeedSwipCard, must be “N”.
      #
      # ==== Options
      # * <tt>:encryption_key_id</tt> -- used to retrieve the private key, which is required for decryption
      # * <tt>:encryption_target</tt> -- type of data that is being encrypted
      # * <tt>:encrypted_block</tt> -- track data or card number provided in an encrypted block. be Present when card data is encrypted
      def add_encryption_data_group(post, options)
        requires!(options, [:encryption_target] + ENCRYPT_TARGETS, :encryption_key_id) if options[:encrypted_block].present?
        optional_assign(post, :KeyID, options[:encryption_key_id])
        optional_assign(post, :EncrtTrgt, options[:encryption_target])
        optional_assign(post, :EncrptBlock, options[:encrypted_block])
      end

      def error_code_from(response)
        code = response['ResponseCode']
        STANDARD_ERROR_CODE_MAPPING[code]
      end

      def parse(body)
        fields = {}
        CGI::parse(body).each do |k, v|
          fields[k.to_s] = v.kind_of?(Array) ? v[0] : v
        end
        fields
      end

      def commit(action, parameters)
        data = ssl_post(target_url, post_data(action, parameters))
        response = parse(data)
        message = message_from(response)

        success = response['Status'] == STATUS_SUCCESS

        Response.new(success,
                     success ? 'Transaction approved' : response['ResponseText'],
                     response,
                     test: test?,
                     authorization: response['GTRC'],
                     avs_result: { :code => response['AVSResultCode'] },
                     :cvv_result => response['CCVResultCode'],
                     :emv_authorization => emv_authorization_from_response(response),
                     :error_code => success ? nil : error_code_from(response)
        )
      end

      def message_from(response)
        MESSAGES.fetch(response['response_code'].to_i, false) || response['message']
      end

      def optional_assign(target, key, source)
        target[key] = source if source.present?
      end

      def post_data(action, parameters = {})
        post = {:TransType => action}

        post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" unless value.nil? }.compact.join("&")
      end

      def target_url
        test? ? self.test_url : self.live_url
      end
    end
  end
end
