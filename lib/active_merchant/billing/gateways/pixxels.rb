module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PixxelsGateway < Gateway
      include Empty

      SUCCESS_CODE = 0
      SOFT_DECLINE_CODES = [65536, 65539, 65542, 65543, 65545, 65547, 65553, 65554, 65556, 65564, 65565, 65566, 65567, 65575].freeze

      self.test_url = self.live_url = 'https://qa-transactions.pixxlesportal.com/api/Transactions/payment/direct'
      self.default_currency = 'GBP'
      self.money_format = :dollars
      self.supported_countries = ['GB']
      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'https://pixxles.com/'
      self.display_name = 'Pixxels'

      def initialize(options = {})
        requires!(options, :merchant_id, :signature_key)
        super

        @response_http_code = nil
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_device(post, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_three_d_url(post, options)

        commit('SALE', post)
      end

      def pre_authorize(options)
        post = {}
        add_three_ds_fields(options)

        commit('SALE', post)
      end

      def confirm(options)
        post = {}
        add_three_ds_fields(options)

        commit('SALE', post)
      end

      def cancel(authorization, options)
        post = {}
        add_reference(post, authorization)

        commit('CANCEL', post)
      end

      def refund(amount, authorization, options)
        post = {}
        add_refund_details(post, amount, options)
        add_reference(post, authorization)

        commit('REFUND_SALE', post)
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = money.to_s
        post[:orderRef] = options[:order_id]
        post[:currencyCode] = options[:currency] || currency(money)
        post[:transactionUnique] = generate_random_uuid
        post[:type] = '1'
      end

      def add_payment_method(post, payment_method, options)
        post[:cardNumber] = payment_method.card_number
        # post[:cardCVV] = payment_method.verification_value unless empty?(payment_method.verification_value)
        post[:cardCVV] = '356'
        post[:cardExpiryMonth] = format(payment_method.month, :two_digits)
        post[:cardExpiryYear] = format(payment_method.year, :two_digits)
      end

      def add_customer_data(post, options)
        post[:customerEmail] = options[:email]
        post[:remoteAddress] = options[:ip]

        if (billing_address = options[:billing_address])
          post[:customerName] = billing_address[:name]
          post[:customerAddress] = billing_address[:address1]
          post[:customerTown] = billing_address[:city]
          post[:customerCountryCode] = billing_address[:country]
          post[:customerPostcode] = billing_address[:zip]
          post[:customerPhone] = billing_address[:phone] if billing_address[:phone]
        end
      end

      def add_three_d_url(post, options)
        redirect_links = options[:redirect_links]
        return unless redirect_links

        post[:threeDSRedirectURL] = redirect_links[:callback_url]
      end

      def add_three_ds_fields(options)
        if (three_d_secure = options[:pixel_three_d_secure])
          post[:threeDSRef] = three_d_secure[:threeDSRefNew] if three_d_secure[:threeDSRefNew]
          post["threeDSResponse[threeDSMethodData]"] = three_d_secure[:threeDSMethodDataNew] if three_d_secure[:threeDSMethodDataNew]
          post["threeDSResponse[cres]"] = three_d_secure[:threeDSCres] if three_d_secure[:threeDSCres]
        end
      end

      def add_device(post, options)
        if (details = options[:browser_details])
          post[:deviceAcceptCharset] = details[:accept_charset]
          post[:deviceAcceptContent] = details[:accept_content]
          post[:deviceAcceptEncoding] = details[:accept_encoding]
          post[:deviceAcceptLanguage] = details[:accept_language]
          post[:deviceCapabilities] = details[:capabilities]
          post[:deviceChannel] = details[:channel]
          post[:deviceIdentity] = details[:identity]
          post[:deviceScreenResolution] = details[:screen_resolution]
          post[:deviceTimeZone] = details[:time_zone]
        end
      end

      def add_reference(post, authorization)
        transaction_id, = split_authorization(authorization)
        post[:xref] = transaction_id
      end

      def add_refund_details(post, amount, options)
        post[:amount] = amount
        post[:orderRef] = options[:order_id]
      end

      def commit(action, params)
        params[:action] = action
        params[:merchantID] = @options[:merchant_id]
        sorted_params = params.sort.to_h

        sorted_params["signature"] = get_signature(sorted_params)
        raw_response = ssl_post(url, post_data(action, sorted_params), headers)
        response = parse(raw_response)
        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          error_code: succeeded ? nil : error_code_from(response),
          authorization: authorization_from(response, sorted_params[:payment], action),
          avs_result: AVSResult.new(code: response[:avsresponse]),
          cvv_result: CVVResult.new(response[:cvvresponse]),
          test: test?,
          response_type: response_type(response[:responseCode]&.to_i),
          response_http_code: @response_http_code,
          request_endpoint: url,
          request_method: :post,
          request_body: sorted_params
        )
      end

      def authorization_from(response, payment_type, action)
        authorization = response[:xref]
        [authorization, payment_type].join('#')
      end

      def split_authorization(authorization)
        authorization.split('#')
      end

      def headers
        headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
        headers
      end

      def post_data(action, params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        Hash[CGI::parse(body).map { |k, v| [k.intern, v.first] }]
      end

      def success_from(response)
        response[:responseCode] == '0'
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response[:responseMessage] == "3DS authentication required" ? "3DS_REQUIRED" : response[:responseMessage]
        end
      end

      def error_code_from(response)
        response[:responseCode]
      end

      def response_type(code)
        if code == SUCCESS_CODE
          0
        elsif SOFT_DECLINE_CODES.include?(code)
          1
        else
          2
        end
      end

      def handle_response(response)
        @response_http_code = response.code.to_i
        case @response_http_code
        when 200...300
          response.body
        else
          raise ResponseError.new(response)
        end
      end

      def generate_random_uuid
        SecureRandom.uuid
      end

      def get_signature(params)
        signature = params.map { |k, v| "#{CGI::escape(k.to_s)}=#{CGI::escape(v.to_s)}" }.join('&')
        signature += @options[:signature_key]
        signature.gsub!(/(\r\n|\n\r|\r)/, "\n")

        Digest::SHA512.hexdigest(signature)
      end
    end
  end
end
