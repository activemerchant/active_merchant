module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NuveiGateway < Gateway
      self.test_url = 'https://ppp-test.safecharge.com/ppp/api/v1/'
      self.live_url = 'https://secure.safecharge.com/ppp/api/v1/'

      # TODO: Is there any limitation here with Nuvei?
      self.supported_countries = %w(AT AU BE BG BR CH CY CZ DE DK EE ES FI FR GB GI GR HK HU IE IS IT LI LT LU LV MC MT MX NL NO PL PT RO SE SG SK SI US)
      self.default_currency = 'USD'
      
      # TODO: Is there any limitation here with Nuvei?
      self.currencies_without_fractions = %w(CVE DJF GNF IDR JPY KMF KRW PYG RWF UGX VND VUV XAF XOF XPF)

      # TODO: What should this value be?
      self.currencies_with_three_decimal_places = %w(BHD IQD JOD KWD LYD OMR TND)

      # TODO: Is there any limitation here with Nuvei?
      self.supported_cardtypes = %i[visa master american_express diners_club jcb dankort maestro discover elo naranja cabal unionpay]

      self.homepage_url = 'https://www.nuvei.com/'
      self.display_name = 'Nuvei'

      def initialize(options = {})
        requires!(options, :merchantId, :merchantSiteId, :secret)
        @merchant_id, @merchant_site_id, @secret = options.values_at(:merchantId, :merchantSiteId, :secret)
        super
      end

      def purchase(money, payment, options = {})
        if options[:execute_threed] || options[:threed_dynamic]
          authorize(money, payment, options)
        else
          MultiResponse.run do |r|
            r.process { authorize(money, payment, options) }
            r.process { capture(money, r.authorization, capture_options(options)) }
          end
        end
      end

      def authorize(money, payment, options = {})
        session_tok = open_session()
        post = init_post()
        post[:session_tok] = session_tok
        post[:merchantId] = @merchant_id
        post[:merchantSiteId] = @merchant_site_id
        post[:clientRequestId] = options[:orderId]
        # TODO: Is this correct?
        post[:amount] = money
        # TODO: Is this correct?
        post[:currency] = options[:currency] || self.default_currency
        # TODO: What is this?
        # post[:userTokenId] = options[:invoiceId]
        #TODO: Is this correct?
        post[:clientUniqueId] = options[:invoiceId]

        post[:paymentOption] = {
          :card => {
            :cardNumber => payment.number,
            :cardHolderName => payment.name,
            :expirationMonth => format(payment.month, :two_digits),
            :expirationYear => format(payment.year, :four_digits_year),
            :CVV => payment.verification_value
          }
        }

        # TODO: Finish filling in device details
        post[:deviceDetails] = {
          #TODO: This is wrong... Find right value for IP
          :ipAddress => options[:IPAddr]
        }

        # TODO: Finish filling in billing address
        post[:billingAddress] = {
          :email => options[:email],
          # Country must be ISO 3166-1-alpha-2 code.
          # See: www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm
          :country => options[:country]
        }

        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        post[:timestamp] = timestamp
        post[:checksum] = get_payment_checksum(post[:clientRequestId], post[:amount], post[:currency], timestamp)
        
        commit('initPayment', post, options)
      end

      def capture(money, authorization, options = {})
        post = init_post(options)

        # Example response:
        # {
        #   "sessionToken" => "",
        #   "merchantId" => "${mId}",
        #   "merchantSiteId" => "${mSiteId}",
        #   "clientRequestId" => "${clientRequestId}",
        #   "amount" => "${amount}",
        #   "currency" => "${currency}",
        #   "userTokenId" => "230811147",
        #   "clientUniqueId" => "12345",
        #   "paymentOption" => {
	#     "card" => {
	#       "cardNumber" => "4111111111111111",
	#       "cardHolderName" => "John Smith",
	#       "expirationMonth" => "12",
	#       "expirationYear" => "2022",
	#       "CVV" => "217"
	#     }
        #   },
        #   "deviceDetails" => {
	#     "ipAddress" => "127.0.0.1"
        #   },
        #   "billingAddress" => {
	#     "email" => "john.smith@email.com",
	#     "country" => "US"
        #   },
        #   "timeStamp" => "${timeStamp}",
        #   "checksum" => "${hash}"
        # }

        commit('capture', post, options)
      end

      def refund(money, authorization, options = {})
        post = init_post(options)
        commit('refund', post, options)
      end
      
      def credit(money, payment, options = {})
        action = 'refundWithData'
        post = init_post(options)
        commit(action, post, options)
      end

      def void(authorization, options = {})
        post = init_post(options)
        commit(endpoint, post, options)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, credit_card, options) }
          options[:idempotency_key] = nil
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      private

      def open_session
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        checksum = get_session_checksum(timestamp)
        parameters = {
          :merchantId => @merchant_id,
          :merchantSiteId => @merchant_site_id,
          :timeStamp => timestamp,
          :checksum => checksum
        }
        
        begin
          raw_response = ssl_post(url('getSessionToken'), post_data(parameters), request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end
      end

      def get_payment_checksum (client_request_id, amount, currency, timestamp)
        print @merchant_id + "\n"
        print @merchant_site_id + "\n"
        print client_request_id + "\n"
        print amount.to_s + "\n"
        print currency + "\n"
        print timestamp + "\n"
        print @secret
        base = @merchant_id + @merchant_site_id + client_request_id + amount.to_s + currency + timestamp + @secret
        checksum = Digest::SHA256.hexdigest base
        print "Payment base: " + base + "\n"
        print checksum
        checksum
      end
      
      def get_session_checksum (timestamp)
        base = @merchant_id + @merchant_site_id + timestamp + @secret
        checksum = Digest::SHA256.hexdigest base
        checksum
      end
      
      def add_merchant_options(post, options)
        post[:merchantId] = options[:merchantId] || @merchant_id
      end

      def parse(body)
        return {} if body.blank?
        print body
        JSON.parse(body)
      end

      def commit(action, parameters, options)
        begin
          raw_response = ssl_post(url(action), post_data(parameters), request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        success = success_from(action, response, options)
        Response.new(
          success,
          message_from(action, response),
          response,
          authorization: authorization_from(action, parameters, response),
          test: test?,
          error_code: success ? nil : error_code_from(response),
          network_transaction_id: network_transaction_id_from(response),
          avs_result: AVSResult.new(code: avs_code_from(response)),
          cvv_result: CVVResult.new(cvv_result_from(response))
        )
      end

      def url(action)
        if test?
          "#{test_url}#{action}.do"
        else
          "#{live_url}#{action}.do"
        end
      end

      def basic_auth
        Base64.strict_encode64("#{@username}:#{@password}")
      end

      def request_headers(options)
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
        headers['Idempotency-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def success_from(action, response, options)
        if %w[RedirectShopper ChallengeShopper].include?(response.dig('resultCode')) && !options[:execute_threed] && !options[:threed_dynamic]
          response['refusalReason'] = 'Received unexpected 3DS authentication response. Use the execute_threed and/or threed_dynamic options to initiate a proper 3DS flow.'
          return false
        end
        case action.to_s
        when 'authorise', 'authorise3d'
          %w[Authorised Received RedirectShopper].include?(response['resultCode'])
        when 'capture', 'refund', 'cancel', 'cancelOrRefund'
          response['response'] == "[#{action}-received]"
        when 'adjustAuthorisation'
          response['response'] == 'Authorised' || response['response'] == '[adjustAuthorisation-received]'
        when 'storeToken'
          response['result'] == 'Success'
        when 'disable'
          response['response'] == '[detail-successfully-disabled]'
        when 'refundWithData'
          response['resultCode'] == 'Received'
        else
          false
        end
      end

      def message_from(action, response)
        return authorize_message_from(response) if %w(authorise authorise3d authorise3ds2).include?(action.to_s)

        response['response'] || response['message'] || response['result'] || response['resultCode']
      end

      def authorize_message_from(response)
        if response['refusalReason'] && response['additionalData'] && response['additionalData']['refusalReasonRaw']
          "#{response['refusalReason']} | #{response['additionalData']['refusalReasonRaw']}"
        else
          response['refusalReason'] || response['resultCode'] || response['message'] || response['result']
        end
      end

      def authorization_from(action, parameters, response)
        return nil if response['pspReference'].nil?

        recurring = response['additionalData']['recurring.recurringDetailReference'] if response['additionalData']
        recurring = response['recurringDetailReference'] if action == 'storeToken'

        "#{parameters[:originalReference]}##{response['pspReference']}##{recurring}"
      end

      def init_post(options = {})
        post = {}
        # add_merchant_options(post, options)
        post[:reference] = options[:order_id][0..79] if options[:order_id]
        post
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end

      def unsupported_failure_response(initial_response)
        Response.new(
          false,
          'Recurring transactions are not supported for this card type.',
          initial_response.params,
          authorization: initial_response.authorization,
          test: initial_response.test,
          error_code: initial_response.error_code,
          avs_result: initial_response.avs_result,
          cvv_result: initial_response.cvv_result[:code]
        )
      end

      def card_not_stored?(response)
        response.authorization ? response.authorization.split('#')[2].nil? : true
      end
    end
  end
end
