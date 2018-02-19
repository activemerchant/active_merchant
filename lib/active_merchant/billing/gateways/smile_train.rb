# SmileTrain
# Is not a gateway per se, it's an API that communicates with Braintree
# and Salesforce
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SmileTrainGateway < Gateway
      self.live_url = 'https://web.smiletrain.org/api/v2/donate'
      self.test_url = 'https://p2picrstagingwebos7.icreondemoserver.com/api/v2/donate'

      self.supported_countries = ['US', 'GB']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.smiletrain.org/'
      self.display_name = 'Smile Train'

      self.money_format = :dollars

      CURRENCY_CODES = {
        'USD' => 1,
        'GBP' => 2
      }.freeze

      FREQUENCY_CODES = {
        'once'     => 1,
        'monthly'  => 2,
        'annual'   => 3
      }.freeze

      PHONE_TYPE = {
        'mobile' => 1,
        'home'   => 2,
        'work'   => 3,
        'none'   => 4
      }.freeze

      def initialize(options={})
        requires!(options, :email, :token)
        super
      end

      # public
      # we only provide support for purchase
      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        add_subscription_data(post, options)
        add_metadata(post, options)

        commit('sale', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: )\w+), '\1[FILTERED]').
          gsub(%r((cardNumber\\\":\\\")\d+)i, '\1[FILTERED]').
          gsub(%r((cvv\\\":\\\")\d+)i, '\1[FILTERED]')
      end

      private

      def add_metadata(post, options)
        post[:domainName] = currency_code(options[:currency])
        post[:submittedBy] = options[:submitted_by]
        post[:mailcode] = options[:mailcode]
      end

      def add_subscription_data(post, options)
        post[:emailSubscription] = options[:email_subscription]
        post[:mailSubscription] = options[:mail_subscription]
        post[:mobileSubscription] = options[:mobile_subscription]
        post[:phoneSubscription] = options[:phone_subscription]
        post[:giftAidChoice] = options[:gift_aid_choice]
      end

      def add_customer_data(post, options)
        post[:firstName] = options[:first_name]
        post[:lastName] = options[:last_name]
        post[:email] = options[:email]
        post[:gender] = options[:gender]
        post[:dateOfBirth] = options[:dob]

      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:streetAddress] = address[:address1] if address[:address1]
          post[:streetAddress2] = address[:address2] if address[:address2]
          post[:country] = address[:country] if address[:country]
          post[:zipCode] = address[:zip] if address[:zip]
          post[:state] = address[:state] if address[:state]
          post[:city] = address[:city] if address[:city]
          post[:phoneNumber] = address[:phone] if address[:phone]
          post[:selectPhoneType] = phone_type_code(options[:phone_type])
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = currency_code((options[:currency] || currency(money)))
        post[:frequency] = frequency_code(options[:frequency])
      end

      def add_payment(post, payment)
        post[:cardNumber] = payment.number
        post[:cardMonthExp] = payment.month
        post[:cardYearExp] = payment.year
        post[:cvv] = payment.verification_value if payment.verification_value?
        post[:billingTitle] = payment.name if payment.name
      end

      def parse(body)
        body.present? ? JSON.parse(body) : {}
      end

      def headers
        {
          'Authorization' => encoded_token,
          'X-ST-AUTH'     => x_st_auth,
          'Content-type'  => 'application/json',
        }
      end

      def encoded_token
        Base64.strict_encode64("#{@options[:email]}:#{@options[:token]}")
      end

      def x_st_auth
        test? ? 'test' : 'donation'
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        [200, 204].include?(response['ResponseCode']) &&
          response['ResponseData'].key?('transactionStatus') &&
          response['ResponseData']['transactionStatus'] == 'Success'
      end

      def message_from(response)
        response['ResponseMessage']
      end

      def authorization_from(response)
        response['ResponseData']['transactionId'] if success_from(response)
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          response['ResponseCode']
        end
      end

      # private
      # simple lookup of the currency code, default to USD
      def currency_code(currency)
        CURRENCY_CODES.fetch(currency, 1)
      end

      # private
      # simple lookup of the frequency, defaults to once
      def frequency_code(frequency)
        FREQUENCY_CODES.fetch(frequency, 1)
      end

      # private
      # simple lookup of the selected phone type, defaults to none
      def phone_type_code(phone_type)
        PHONE_TYPE.fetch(phone_type, 4)
      end
    end
  end
end
