module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardprocessGateway < Gateway
      self.test_url = 'https://test.vr-pay-ecommerce.de/v1/payments'
      self.live_url = 'https://vr-pay-ecommerce.de/v1/payments'

      self.supported_countries = %w[ BE BG CZ DK DE EE IE ES FR HR IT CY LV LT LU
                                     MT HU NL AT PL PT RO SI SK FI SE GB IS LI NO
                                     CH ME MK AL RS TR BA ]
      self.default_currency = 'EUR'
      self.supported_cardtypes = %i[visa master american_express diners_club jcb]

      self.homepage_url = 'https://vr-pay-ecommerce.docs.oppwa.com/'
      self.display_name = 'CardProcess VR-Pay'
      self.money_format = :dollars

      STANDARD_ERROR_CODE_MAPPING = {}

      # Creates a new CardProcess Gateway
      #
      # The gateway requires a valid login, password, and entity ID
      # to be passed in the +options+ hash.
      #
      # === Options
      #
      # * <tt>:user_id</tt> -- The CardProcess user ID
      # * <tt>:password</tt> -- The CardProcess password
      # * <tt>:entity_id</tt> -- The CardProcess channel or entity ID for any transactions
      def initialize(options={})
        requires!(options, :user_id, :password, :entity_id)
        super
        # This variable exists purely to allow remote tests to force error codes;
        # the lack of a setter despite its usage is intentional.
        @test_options = {}
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('DB', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('PA', post)
      end

      def capture(money, authorization, options = {})
        post = {
          id: authorization
        }
        add_invoice(post, money, options)
        commit('CP', post)
      end

      def refund(money, authorization, options = {})
        post = {
          id: authorization
        }
        add_invoice(post, money, options)
        commit('RF', post)
      end

      def credit(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('CD', post)
      end

      def void(authorization, _options = {})
        post = {
          id: authorization
        }
        commit('RV', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run do |r|
          r.process { authorize(100, credit_card, options) }
          r.process { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r{(authentication\.[^=]+=)[^&]+}, '\1[FILTERED]').
          gsub(%r{(card\.number=)\d+}, '\1[FILTERED]').
          gsub(%r{(cvv=)\d{3,4}}, '\1[FILTERED]\2')
      end

      private

      def add_customer_data(post, options)
        post['customer.ip'] = options[:ip] if options[:ip]
      end

      def add_address(post, _card, options)
        if (address = options[:billing_address] || options[:address])
          post[:billing] = hashify_address(address)
        end

        if (shipping = options[:shipping_address])
          post[:shipping] = hashify_address(shipping)
        end
      end

      def add_invoice(post, money, options)
        return if money.nil?

        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:merchantInvoiceId] = options[:merchant_invoice_id] if options[:merchant_invoice_id]
        post[:merchantTransactionId] = options[:merchant_transaction_id] if options[:merchant_transaction_id]
        post[:transactionCategory] = options[:transaction_category] if options[:transaction_category]
      end

      def add_payment(post, payment)
        return if payment.is_a?(String)

        post[:paymentBrand] = payment.brand.upcase if payment.brand
        post[:card] ||= {}
        post[:card][:number] = payment.number
        post[:card][:holder] = payment.name
        post[:card][:expiryMonth] = sprintf('%02d', payment.month)
        post[:card][:expiryYear] = sprintf('%02d', payment.year)
        post[:card][:cvv] = payment.verification_value
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        if (id = parameters.delete(:id))
          url += "/#{id}"
        end

        begin
          raw_response = ssl_post(url, post_data(action, parameters.merge(@test_options)))
        rescue ResponseError => e
          raw_response = e.response.body
        end
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['result']['avsResponse']),
          cvv_result: CVVResult.new(response['result']['cvvResponse']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        !(response['result']['code'] =~ /^(000\.000\.|000\.100\.1|000\.[36])/).nil?
      end

      def message_from(response)
        response['result']['description']
      end

      def authorization_from(response)
        response['id']
      end

      def post_data(action, parameters = {})
        post = parameters.clone
        post[:authentication] ||= {}
        post[:authentication][:userId] = @options[:user_id]
        post[:authentication][:password] = @options[:password]
        post[:authentication][:entityId] = @options[:entity_id]
        post[:paymentType] = action
        dot_flatten_hash(post).map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      def error_code_from(response)
        unless success_from(response)
          case response['result']['code']
          when '100.100.101'
            STANDARD_ERROR_CODE[:incorrect_number]
          when '100.100.303'
            STANDARD_ERROR_CODE[:expired_card]
          when /100\.100\.(201|301|305)/
            STANDARD_ERROR_CODE[:invalid_expiry_date]
          when /100.100.60[01]/
            STANDARD_ERROR_CODE[:invalid_cvc]
          when '800.100.151'
            STANDARD_ERROR_CODE[:invalid_number]
          when '800.100.153'
            STANDARD_ERROR_CODE[:incorrect_cvc]
          when /800.800.(102|302)/
            STANDARD_ERROR_CODE[:incorrect_address]
          when '800.800.202'
            STANDARD_ERROR_CODE[:invalid_zip]
          when '800.100.166'
            STANDARD_ERROR_CODE[:incorrect_pin]
          when '800.100.171'
            STANDARD_ERROR_CODE[:pickup_card]
          when /^(200|700)\./
            STANDARD_ERROR_CODE[:config_error]
          when /^(800\.[17]00|800\.800\.[123])/
            STANDARD_ERROR_CODE[:card_declined]
          when /^(900\.[1234]00)/
            STANDARD_ERROR_CODE[:processing_error]
          else
            STANDARD_ERROR_CODE[:processing_error]
          end
        end
      end

      def hashify_address(address)
        hash = {}
        hash[:street1] = address[:address1] if address[:address1]
        hash[:street2] = address[:address2] if address[:address2]
        hash[:city] = address[:city] if address[:city]
        hash[:state] = address[:state] if address[:state]
        hash[:postcode] = address[:zip] if address[:zip]
        hash[:country] = address[:country] if address[:country]
        hash
      end

      def dot_flatten_hash(hash, prefix = '')
        h = {}
        hash.each_pair do |k, v|
          if v.is_a?(Hash)
            h.merge!(dot_flatten_hash(v, prefix + k.to_s + '.'))
          else
            h[prefix + k.to_s] = v
          end
        end
        h
      end
    end
  end
end
