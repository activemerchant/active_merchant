module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PlaceToPayGateway < Gateway
      self.test_url = 'https://test.placetopay.ec/rest'
      self.live_url = 'https://placetopay.ec/rest'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://test.placetopay.ec/'
      self.display_name = 'Place To Pay'

      self.money_format = :dollars

      STANDARD_ERROR_CODE_MAPPING = {
        '05' => STANDARD_ERROR_CODE[:card_declined],
        '10' => STANDARD_ERROR_CODE[:card_declined],
        '14' => STANDARD_ERROR_CODE[:invalid_number],
        '19' => STANDARD_ERROR_CODE[:invalid_cvc],
        '21' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '22' => STANDARD_ERROR_CODE[:incorrect_cvc],
      }

      def initialize(options={})
        requires!(options, :login, :secret_key)
        super
      end

      def information(money, payment, options={})
        post = {}

        add_auth_data(post)
        add_misc_data(post, options)
        add_instrument_data(post, payment, options)
        add_payment_data(post, money, options)

        commit('/gateway/information', post)
      end

      def interests(money, payment, options={})
        post = {}

        add_auth_data(post)
        add_misc_data(post, options)
        add_instrument_data(post, payment, options)
        add_payment_data(post, money, options)

        commit('/gateway/interests', post)
      end

      def otp(money, payment, options={})
        post = {}

        add_auth_data(post)
        add_misc_data(post, options)
        add_instrument_data(post, payment, options)
        add_payment_data(post, money, options)

        commit('/gateway/otp/generate', post)
      end

      def otp_validation(money, payment, options={})
        post = {}

        add_auth_data(post)
        add_misc_data(post, options)
        add_instrument_data(post, payment, options)
        add_payment_data(post, money, options)

        commit('/gateway/otp/validate', post)
      end

      def store(payment, options)
        post = {}

        add_auth_data(post)
        add_misc_data(post, options)
        add_instrument_data(post, payment, options)
        add_customer_data(post, payment, options)

        commit('/gateway/tokenize', post)
      end

      def purchase(money, payment, options={})
        post = {}

        add_auth_data(post)
        add_misc_data(post, options)
        add_payment_data(post, money, options)
        add_instrument_data(post, payment, options)
        add_customer_data(post, payment, options)
        post[:buyer] = customer_data(payment, options)

        endpoint = options['otp'] ? '/gateway/safe-process' : '/gateway/process'
        
        commit(endpoint, post)
      end

      def void(authorization, options = {})
        post = {}

        add_auth_data(post)
        add_misc_data(post, options)

        post[:internalReference] = options[:internal_reference]
        post[:authorization] = authorization
        post[:action] = 'reverse'

        commit('/gateway/transaction', post)
      end

      def search(money, options)
        post = {}

        add_auth_data(post)
        options[:reference] = options[:reference]
        options[:amount] = amount_base(money, options)

        commit('/gateway/search', post)        
      end

      def add_customer_data(post, payment, options)
        post[:payer] = customer_data(payment, options)
      end

      def add_address_data(options)
        address = {}

        if options[:address].present?
          address[:street] = options[:address][:street]
          address[:city] = options[:address][:city]
          address[:state] = options[:address][:state]
          address[:postalCode] = options[:address][:postal_code]
          address[:country] = options[:address][:country]
          address[:phone] = options[:address][:phone]
        end

        address
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r(("card\\?":{.*\\?"number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("card\\?":{.*\\?"cvv\\?":\\?")\d+), '\1[FILTERED]')  
      end

      private

      def add_instrument_data(post, payment, options={})
        instrument = {}

        instrument[:card] = {}
        instrument[:card][:number] = payment.number
        instrument[:card][:expirationMonth] = payment.month
        instrument[:card][:expirationYear] = payment.year
        instrument[:card][:cvv] = payment.verification_value

        if options[:credit].present?
          valid_group_codes = %w(C D M P X)
          instrument[:credit] = {}
          instrument[:credit][:code] = options[:credit][:code] 
          instrument[:credit][:type] = options[:credit][:type]
          instrument[:credit][:groupCode] = valid_group_codes
            .grep(options[:credit][:group_code]).first
          instrument[:credit][:installment] = options[:credit][:installment]
          instrument[:credit][:installments] = options[:credit][:installments]  
        end

        if options[:otp].present?
          instrument[:otp] = options[:otp]
        end

        post[:instrument] = instrument
      end

      def customer_data(payment, options)
        person = {}

        person[:documentType] = options[:person_id_type] if options[:person_id_type]
        person[:document] = options[:document] if options[:document]
        person[:name] = payment.first_name
        person[:surname] = payment.last_name 
        person[:company] = options[:company] if options[:mobile]
        person[:email] = options[:email]
        person[:address] = add_address_data(options)
        person[:mobile] = options[:mobile_phone] if options[:mobile_phone]

        person
      end

      def add_payment_data(post, money, options)
        payment = {}

        payment[:reference] = options[:reference]
        payment[:description] = options[:description]
        payment[:amount] = add_amount(money, options)

        if options[:dispersion].present?
          payment[:dispersion] = add_dispersion(money, options[:dispersion])
        end

        post[:payment] = payment
      end

      def add_amount(money, options)
        amount = {}

        amount = amount_base(money, options)
        amount[:taxes] = tax_details(money, options[:tax]) if options[:tax].present?
        amount[:details] = amount_details(amount, options[:payment_details]) if options[:payment_details].present?

        amount
      end

      def amount_base(money, options)
        {
          currency: (options[:currency] || currency(money)),
          total:  amount(money),
        }
      end

      def tax_details(money, tax_options)
        valid_taxes_kind = %w(valueAddedTax exciseDuty ice)

        {
          kind: valid_taxes_kind.grep(tax_options[:kind]).first,
          amount: amount(money),
          base: tax_options[:base]
        }
      end

      def amount_details(amount, payment_details_options)
        valid_details_kind = %w(
          discount
          additional
          vatDevolutionBase
          shipping
          handlingFee
          insurance
          giftWrap
          subtotal
          fee
          tip)

        {
          kind: valid_details_kind.grep(payment_details_options[:kind]).first,
          amount: payment_details_options[:amount]
        }
      end

      def add_dispersion(money, options)
        {
          agreement: options[:agreement],
          agreementType: options[:agreement_type],
          amount: amount(money)
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers
        {
          'Content-Type' => 'application/json'
        }
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url) + action

        begin
          raw_response = ssl_post(url, post_data(action, parameters), headers)
          response = parse(raw_response)
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        ['OK', 'APPROVED'].include?(response['status']['status']) 
      end

      def message_from(response)
        response['status']['message']
      end

      def authorization_from(response)
        response['authorization']
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING.fetch(
            response['status']['reason'],
            response['status']['reason'])
        end
      end

      def add_misc_data(post, options={})
        post[:locale] = options[:locale] || 'es_EC'
        post[:ipAddress] = options[:ip] if options[:ip].present?
        post[:userAgetn] = options[:user_agent] if options[:user_agent]
        post[:additional] = options[:additional] if options[:additional]
      end

      def add_auth_data(post)
        secret_key = @options[:secret_key]
        nonce = SecureRandom.alphanumeric(8)
        seed  = Time.now.iso8601
        tran_key = Digest::SHA256.base64digest(nonce + seed + secret_key)

        auth = {}
        auth[:login]    = @options[:login]
        auth[:nonce]    = Base64.strict_encode64(nonce)
        auth[:seed]     = seed
        auth[:tranKey]  = tran_key

        post[:auth] = auth
      end
    end
  end
end
