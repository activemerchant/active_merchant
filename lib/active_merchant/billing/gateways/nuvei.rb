# coding: utf-8
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NuveiGateway < Gateway
      self.test_url = 'https://ppp-test.safecharge.com/ppp/api/v1/'
      self.live_url = 'https://secure.safecharge.com/ppp/api/v1/'
      self.default_currency = 'USD'
      self.homepage_url = 'https://www.nuvei.com/'
      self.display_name = 'Nuvei'

      def initialize(options = {})
        requires!(options, :merchant_id, :merchant_site_id, :secret)
        @merchant_id, @merchant_site_id, @secret = options.values_at(:merchant_id, :merchant_site_id, :secret)
        super
      end

      def purchase(money, payment, options = {})
        post = init_post
        session = open_session
        if session['sessionToken'].blank?
          failed_session_creation(session)
        else
          add_session(post, session)
          add_payment(post, money, payment, options)
          add_device_details(post, options)
          add_billing_address(post, options)
          commit('payment', post, options)
        end
      end

      def refund(money, authorization, options = {})
        post = init_post(options)
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        add_trans_details(post, money, options, timestamp)
        add_refund_details(post, authorization, timestamp)
        commit('refundTransaction', post, options)
      end

      def credit(money, payment, options = {})
        post = init_post(options)
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        add_trans_details(post, money, options, timestamp)
        add_device_details(post, options)
        add_payout_details(post, options, timestamp)
        commit('payout', post, options)
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
          e.response.body
          response = parse(raw_response)
        end
      end

      def failed_session_creation(response)
        Response.new(
          false,
          "Failed to open session",
          response,
          test: test?
        )
      end

      def get_payment_checksum (client_request_id, amount, currency, timestamp)
        base = @merchant_id + @merchant_site_id + client_request_id +
               amount.to_s + currency + timestamp + @secret
        Digest::SHA256.hexdigest base
      end

      def get_payout_checksum (client_request_id, amount, currency, timestamp)
        base = @merchant_id + @merchant_site_id + client_request_id +
               amount.to_s + currency + timestamp + @secret
        Digest::SHA256.hexdigest base
      end
      
      def get_refund_checksum (client_request_id, amount, currency, transaction_id, timestamp)
        base = @merchant_id + @merchant_site_id + client_request_id +
               amount.to_s + currency + transaction_id + timestamp + @secret
        Digest::SHA256.hexdigest base
      end
      
      def get_session_checksum (timestamp)
        base = @merchant_id + @merchant_site_id + timestamp + @secret
        Digest::SHA256.hexdigest base
      end

      def add_session(post, session)
        post[:sessionToken] = session['sessionToken']
      end

      def add_device_details(post, options)
        post[:deviceDetails] = {
          :ipAddress => options[:ip]
        }
      end

      def add_billing_address(post, options)
        post[:billingAddress] = {
          :email => options[:email],
          # Country must be ISO 3166-1-alpha-2 code.
          # See: www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm
          :country => options.dig(:billing_address, :country)
        }
      end
      
      def add_refund_details(post, authorization, timestamp)
        post[:relatedTransactionId] = authorization
        post[:checksum] = get_refund_checksum(post[:clientRequestId], post[:amount], post[:currency], post[:relatedTransactionId], timestamp)
      end
      
      def add_payment (post, money, payment, options)
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        add_trans_details(post, money, options, timestamp)
        add_payment_option(post, payment)
        post[:checksum] = get_payment_checksum(post[:clientRequestId], post[:amount], post[:currency], timestamp)
        post[:userTokenId] = options[:user_token_id]
      end

      def add_payment_option(post, payment)
        post[:paymentOption] = {
          :card => {
            :cardNumber => payment.number,
            :cardHolderName => payment.name,
            :expirationMonth => format(payment.month, :two_digits),
            :expirationYear => format(payment.year, :four_digits_year),
            :CVV => payment.verification_value,
          }
        }
      end
      
      def add_trans_details(post, money, options, timestamp)
        post[:amount] = amount(money)
        post[:clientRequestId] = options[:order_id].to_s
        post[:currency] = options[:currency] || currency(money)
        post[:timeStamp] = timestamp
      end

      def add_payout_details(post, options, timestamp)
        post[:userTokenId] = options[:user_token_id]
        post[:userPaymentOption] = {
          :userPaymentOptionId => options[:user_payment_option_id]
        }
        post[:checksum] = get_payout_checksum(post[:clientRequestId], post[:amount], post[:currency], timestamp)
      end
      
      def add_merchant_options(post)
        post[:merchantId] = @merchant_id
        post[:merchantSiteId] = @merchant_site_id
      end

      def parse(body)
        body.blank? ? {} :  JSON.parse(body)
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
          message_from(success, response),
          response,
          authorization: authorization_from(success, action, response),
          test: test?,
          avs_result: AVSResult.new(code: avs_code_from(response)),
          cvv_result: CVVResult.new(cvv_result_from(response))
        )
      end
      
      def avs_code_from(response)
        response.dig('paymentOption', 'card', 'avsCode')
      end

      def cvv_result_from(response)
        response.dig('paymentOption', 'card', 'cvv2Reply')
      end

      def url(action)
        if test?
          "#{test_url}#{action}.do"
        else
          "#{live_url}#{action}.do"
        end
      end

      def request_headers(options)
        headers = {
          'Content-Type' => 'application/json',
        }
        headers
      end

      def success_from(action, response, options)
        case action.to_s
        when 'payment', 'refundTransaction', 'payout'
          response['status'] == "SUCCESS" and response['transactionStatus'] == "APPROVED"
        else
          false
        end
        
      end

      def message_from(success, response)
        if success
          'Succeeded'
        elsif !response['reason'].blank?
          response['reason']
        elsif !response['gwErrorReason'].blank?
          response['gwErrorReason']
        else
          'Failed'
        end
      end

      def authorization_from(success, action, response)
        if !success
          nil
        elsif action == "payment"
          # If a userPaymentOptionId exists, then the payment authorizations
          # will be in the format: {transactionId}|{userPaymentOptionId}
          # The userPaymentOptionId is required for posting credit to this
          # card in the future. This value is blank if userTokenId is blank when
          # posting the payment.
          authorization = response['transactionId'].to_s
          upo_id = response.dig('paymentOption', 'userPaymentOptionId')
          if !upo_id.blank?
            authorization += "|" + upo_id
          end

        elsif !response['transactionId'].nil?
          authorization = response['transactionId'].to_s
        else 
          authorization = response["internalRequestId"].to_s
        end

        authorization
      end

      def init_post(options = {})
        post = {}
        add_merchant_options(post)
        post
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end

    end
  end
end
