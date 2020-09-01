require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Important note:
    # ===
    # Culqi merchant accounts are configured for either purchase or auth/capture
    # modes. This is configured by Culqi when setting up a merchant account and
    # largely depends on the transaction acquiring bank. Be sure to understand how
    # your account was configured prior to using this gateway.
    class CulqiGateway < Gateway
      self.display_name = 'Culqi'
      self.homepage_url = 'https://www.culqi.com'

      self.test_url = 'https://staging.paymentz.com/transaction/'
      self.live_url = 'https://secure.culqi.com/transaction/'

      self.supported_countries = ['PE']
      self.default_currency = 'PEN'
      self.money_format = :dollars
      self.supported_cardtypes = %i[visa master diners_club american_express]

      def initialize(options={})
        requires!(options, :merchant_id, :terminal_id, :secret_key)
        super
      end

      def purchase(amount, payment_method, options={})
        authorize(amount, payment_method, options)
      end

      def authorize(amount, payment_method, options={})
        if payment_method.is_a?(String)
          action = :tokenpay
        else
          action = :authorize
        end
        post = {}
        add_credentials(post)
        add_invoice(action, post, amount, options)
        add_payment_method(post, payment_method, action, options)
        add_customer_data(post, options)
        add_checksum(action, post)

        commit(action, post)
      end

      def capture(amount, authorization, options={})
        action = :capture
        post = {}
        add_credentials(post)
        add_invoice(action, post, amount, options)
        add_reference(post, authorization)
        add_checksum(action, post)

        commit(action, post)
      end

      def void(authorization, options={})
        action = :void
        post = {}
        add_credentials(post)
        add_invoice(action, post, nil, options)
        add_reference(post, authorization)
        add_checksum(action, post)

        commit(action, post)
      end

      def refund(amount, authorization, options={})
        action = :refund
        post = {}
        add_credentials(post)
        add_invoice(action, post, amount, options)
        add_reference(post, authorization)
        add_checksum(action, post)

        commit(action, post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(1000, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def verify_credentials
        response = void('0', order_id: '0')
        response.message.include? 'Transaction not found'
      end

      def store(credit_card, options={})
        action = :tokenize
        post = {}
        post[:partnerid] = options[:partner_id] if options[:partner_id]
        post[:cardholderid] = options[:cardholder_id] if options[:cardholder_id]
        add_credentials(post)
        add_payment_method(post, credit_card, action, options)
        add_customer_data(post, options)
        add_checksum(action, post)

        commit(action, post)
      end

      def invalidate(authorization, options={})
        action = :invalidate
        post = {}
        post[:partnerid] = options[:partner_id] if options[:partner_id]
        add_credentials(post)
        post[:token] = authorization
        add_checksum(action, post)

        commit(action, post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((cardnumber=)\d+), '\1[FILTERED]').
          gsub(%r((cvv=)\d+), '\1[FILTERED]')
      end

      private

      def add_credentials(post)
        post[:toid] = @options[:merchant_id]
        post[:totype] = 'Culqi'
        post[:terminalid] = @options[:terminal_id]
        post[:language] = 'ENG'
      end

      def add_invoice(action, post, money, options)
        case action
        when :capture
          post[:captureamount] = amount(money)
        when :refund
          post[:refundamount] = amount(money)
          post[:reason] = 'none'
        else
          post[:amount] = amount(money)
        end

        post[:description] = options[:order_id]
        post[:redirecturl] = options[:redirect_url] || 'http://www.example.com'
      end

      def add_payment_method(post, payment_method, action, options)
        if payment_method.is_a?(String)
          post[:token] = payment_method
          post[:cvv] = options[:cvv] if options[:cvv]
        else
          post[:cardnumber] = payment_method.number
          post[:cvv] = payment_method.verification_value
          post[:firstname], post[:lastname] = payment_method.name.split(' ')
          if action == :tokenize
            post[:expirymonth] = format(payment_method.month, :two_digits)
            post[:expiryyear] = format(payment_method.year, :four_digits)
          else
            post[:expiry_month] = format(payment_method.month, :two_digits)
            post[:expiry_year] = format(payment_method.year, :four_digits)
          end
        end
      end

      def add_customer_data(post, options)
        post[:emailaddr] = options[:email] || 'unspecified@example.com'
        if (billing_address = options[:billing_address] || options[:address])
          post[:street] = [billing_address[:address1], billing_address[:address2]].join(' ')
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:countrycode] = billing_address[:country]
          post[:zip] = billing_address[:zip]
          post[:telno] = billing_address[:phone]
          post[:telnocc] = options[:telephone_country_code] || '051'
        end
      end

      def add_checksum(action, post)
        checksum_elements =
          case action
          when :capture    then  [post[:toid], post[:trackingid], post[:captureamount], @options[:secret_key]]
          when :void       then  [post[:toid], post[:description], post[:trackingid], @options[:secret_key]]
          when :refund     then  [post[:toid], post[:trackingid], post[:refundamount], @options[:secret_key]]
          when :tokenize   then [post[:partnerid], post[:cardnumber], post[:cvv], @options[:secret_key]]
          when :invalidate then [post[:partnerid], post[:token], @options[:secret_key]]
          else [post[:toid], post[:totype], post[:amount], post[:description], post[:redirecturl],
                post[:cardnumber] || post[:token], @options[:secret_key]]
          end

        post[:checksum] = Digest::MD5.hexdigest(checksum_elements.compact.join('|'))
      end

      def add_reference(post, authorization)
        post[:trackingid] = authorization
      end

      ACTIONS = {
        authorize: 'SingleCallGenericServlet',
        capture: 'SingleCallGenericCaptureServlet',
        void: 'SingleCallGenericVoid',
        refund: 'SingleCallGenericReverse',
        tokenize: 'SingleCallTokenServlet',
        invalidate: 'SingleCallInvalidateToken',
        tokenpay: 'SingleCallTokenTransaction'
      }

      def commit(action, params)
        response =
          begin
            parse(ssl_post(url + ACTIONS[action], post_data(action, params), headers))
          rescue ResponseError => e
            parse(e.response.body)
          end

        success = success_from(response)

        Response.new(
          success,
          message_from(response),
          response,
          authorization: success ? authorization_from(response) : nil,
          cvv_result: success ? cvvresult_from(response) : nil,
          error_code: success ? nil : error_from(response),
          test: test?
        )
      end

      def headers
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8'
        }
      end

      def post_data(action, params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        message = 'Invalid JSON response received from CulqiGateway. Please contact CulqiGateway if you continue to receive this message.'
        message += "(The raw response returned by the API was #{body.inspect})"
        {
          'status' => 'N',
          'statusdescription' => message
        }
      end

      def success_from(response)
        response['status'] == 'Y'
      end

      def message_from(response)
        response['statusdescription'] || response['statusDescription']
      end

      def authorization_from(response)
        response['trackingid'] || response['token']
      end

      def cvvresult_from(response)
        CVVResult.new(response['cvvresult'])
      end

      def error_from(response)
        response['resultcode']
      end
    end
  end
end
