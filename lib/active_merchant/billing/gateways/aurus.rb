# frozen-string-literal: true

module ActiveMerchant  #:nodoc: ALL
  module Billing
    class AurusGateway < Gateway
      self.test_url = 'http://localhost:8080/auruspay/aesdk'
      self.live_url = 'http://live.auruspay.com/auruspay/aesdk'

      self.default_currency     = 'USD'
      self.display_name         = 'Aurus Payment Gateway'
      self.homepage_url         = 'http://aurusinc.com'
      self.money_format         = :dollars
      self.supported_countries  = %w[CA US]
      self.supported_cardtypes  = %i[visa master american_express jcb discover]

      # Actions
      CLOSE_TRANSACTION_REQ = :CloseTransaction
      GET_STATUS_REQ        = :GetStatus
      INIT_AESDK_REQ        = :InitAesdk
      TRANSACTION_REQ       = :Trans

      # Endpoints
      INIT_ENDPOINT              = 'initaesdk'
      TRANSACTION_ENDPOINT       = 'authtransaction'
      CLOSE_TRANSACTION_ENDPOINT = 'closeTransaction'

      # Transaction types
      PURCHASE  = '01'
      REFUND    = '02'
      AUTHORIZE = '04' # Pre-Auth
      CAPTURE   = '05' # Post-Auth
      VOID      = '06'

      CURRENCY_USD = '840'
      CURRENCY_MAPPING = {
        'usd' => '840',
        'eur' => '978',
        'aud' => '036',
        'gbp' => '826',
        'cad' => '124',
        'jpy' => '392'
      }.freeze

      LANGUAGE_ENGLISH = '00'
      LANGUAGE_MAPPING = {
        'en'    => '00',
        'en-ca' => '00',
        'en-us' => '00',
        'fr'    => '04',
        'fr-ca' => '04',
        'es'    => '05'
      }.freeze

      APPROVED_RESPONSE_CODES = ['00000', '71004'].freeze
      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        STANDARD_ERROR_CODE[:success] = 'success'
        STANDARD_ERROR_CODE_MAPPING['00000'] = STANDARD_ERROR_CODE[:success]

        Gateway.logger = Logger.new(STDOUT)
        Gateway.logger.level = Logger::DEBUG
        super
      end

      def purchase(money, payment, options = {}); end

      def authorize(money, payment, options = {}); end

      def capture(_money, _authorization, _options = {}); end

      def refund(money, authorization, options = {})
        post = {}
        post[:TransactionType] = REFUND
        add_configure_group(post, options)
        add_card_info_group(post, options[:card_token], options)
        add_amount_group(post, options, money)
        add_trace_group(post, options, authorization)
        add_ecomm_info_group(post, options)
        commit(TRANSACTION_ENDPOINT, TRANSACTION_REQ, post)
      end

      def void(authorization, options = {})
        post = {}
        post[:TransactionType] = VOID
        add_configure_group(post, options)
        add_card_info_group(post, options[:card_token], options)
        add_amount_group(post, options, options[:authorized_amount])
        add_trace_group(post, options, authorization)
        add_ecomm_info_group(post, options)
        commit(TRANSACTION_ENDPOINT, TRANSACTION_REQ, post)
      end

      def verify(credit_card, options = {}); end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      # Add the Amount Group of options - only used for authorize, purchase, refund, & add_tip
      #
      # * <tt>money</tt> -- optional
      # ==== Options
      # * <tt>:tip_amount</tt> -- tip that is in addition to +money+, optional
      # * <tt>:tax_amount</tt> -- tax amount included with +money+, optional
      # * <tt>:cash_back_amount</tt> -- cash back amount included with +money+, optional
      # * <tt>:tax_indicator</tt> -- additional info on tax amount, optional, defaults +Prvded+
      def add_amount_group(post, options, money = nil)
        if money.present?
          tx_amt_details = post[:TransAmountDetails] = {}
          optional_assign(tx_amt_details, :TransactionTotal, money)
        end
        optional_assign(post, :CurrencyCode, CURRENCY_MAPPING[options[:currency_uuid]] || CURRENCY_USD)
      end

      # Add the Request Card Info Group of options - used when card info is from POS, not PDC. and the item,
      # NeedSwipCard, must be N.
      #
      # ==== Options
      def add_card_info_group(post, payment, _options)
        ecomm_info = post[:ECOMMInfo] ||= {}
        ecomm_info[:CardIdentifier] = payment
      end

      # Add the Configure Group of options - used for ALL transactions
      #
      # * <tt>terminal_id_required</tt> -- optional, defaults to true
      # ==== Options
      # * <tt>:merchant_id</tt> -- required
      # * <tt>:terminal_id</tt> -- required
      # * <tt>:password</tt> -- required
      # * <tt>:allow_partial_auth</tt> -- allow partial authorization if full amount is not available; defaults +false+
      def add_configure_group(post, options, terminal_id_required = true)
        optional_assign(post, :LanguageIndicator, LANGUAGE_MAPPING[options[:locale_uuid]] || LANGUAGE_ENGLISH)
      end

      def add_ecomm_info_group(post, _options)
        requires!(@options, :merchant_id, :store_id, :terminal_id)

        post[:EcommerceIndicator] = 'Y'

        ecomm_info = post[:ECOMMInfo] ||= {}
        ecomm_info[:MerchantIdentifier] = @options[:merchant_id]
        ecomm_info[:StoreId] = @options[:store_id]
        ecomm_info[:TerminalId] = @options[:terminal_id]
      end

      # Add the Trace Group of options - used for ALL transactions
      #
      # * <tt>authorization</tt> -- a unique trace number assigned to a transaction by Cloud9 payment and returned in
      #                             the response message. The POS must submit it back for Void / Addtip / Finalize etc
      #                             based previous transactions.
      # ==== Options
      # * <tt>:source_trace_num</tt> -- source trace number provided by the merchant and it uniquely identifies a
      # * transaction, required
      def add_trace_group(post, _options, authorization = nil)
        post[:AurusPayTicketNum] = '000000000000000000'
        if authorization.present?
          ticket_num, transaction_id = authorization.split('|')
          post[:OrigAurusPayTicketNum] = ticket_num
          post[:OrigTransactionIdentifier] = transaction_id
        end
        now = Time.zone.now
        post[:TransactionDate] = now.strftime('%m%d%Y')
        post[:TransactionTime] = now.strftime('%H%M%S')
      end

      def action_request(action)
        (action.to_s + 'Request').to_sym
      end

      def action_response(action)
        action.to_s + 'Response'
      end

      def add_customer_data(_post, _options); end

      def add_address(_post, _creditcard, _options); end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(_post, _payment); end

      def parse(body, action)
        return {} if body.blank?
        response = JSON.parse(body)
        raise ResponseError.new(body) unless response[action_response(action)].present?
        response[action_response(action)]['Response'].present? ? response[action_response(action)]['Response'] : response[action_response(action)]
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Aurus API.'
        msg + "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'Status'       => STATUS_FAIL,
          'ResponseCode' => STANDARD_ERROR_CODE[:processing_error],
          'ResponseText' => msg
        }
      end

      def optional_assign(target, key, source)
        target[key] = source if source.present?
      end

      def response_error(raw_response, action)
        parse(raw_response, action)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def api_request(endpoint, action, parameters = nil)
        raw_response = response = nil
        begin
          endpoint = '/' + endpoint if endpoint&.size&.positive?
          raw_response = ssl_post(target_url + endpoint, post_data(action, parameters), headers(parameters))
          response = parse(raw_response, action)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response, action)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(endpoint, action, parameters)
        response = api_request(endpoint, action, parameters)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['ResponseCode'].in? APPROVED_RESPONSE_CODES
      end

      def message_from(_response); end

      def authorization_from(action, response)
        case action
        when TRANSACTION_REQ
          response['AurusPayTicketNum'] + '|' + response['AuruspayTransactionId']
        else
          'OK' # TODO: flesh out for other calls
        end
      end

      def error_code_from(response)
        if response['ResponseCode'].blank?
          STANDARD_ERROR_CODE[:success]
        else
          STANDARD_ERROR_CODE_MAPPING[response['ResponseCode']] || STANDARD_ERROR_CODE[:processing_error]
        end
      end

      def headers(_options = {})
        {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'User-Agent':   "Aurus/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end

      def post_data(action, parameters = {})
        post = {}
        post[action_request(action)] = parameters

        JSON.generate(post)
      end

      def target_url
        test? ? self.test_url : self.live_url
      end

    end
  end
end
