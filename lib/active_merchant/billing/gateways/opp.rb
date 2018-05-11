module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OppGateway < Gateway
    # = Open Payment Platform
    #
    #  The Open Payment Platform includes a powerful omni-channel transaction processing API,
    #   enabling you to quickly and flexibly build new applications and services on the platform.
    #
    #   This plugin enables connectivity to the Open Payment Platform for activemerchant.
    #
    # For any questions or comments please contact support@payon.com
    #
    # == Usage
    #
    #   gateway = ActiveMerchant::Billing::OppGateway.new(
    #      user_id: 'merchant user id',
    #      password: 'password',
    #      entity_id: 'entity id',
    #   )
    #
    #   # set up credit card object as in main ActiveMerchant example
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #     :type       => 'visa',
    #     :number     => '4242424242424242',
    #     :month      => 8,
    #     :year       => 2009,
    #     :first_name => 'Bob',
    #     :last_name  => 'Bobsen'
    #     :verification_value: '123')
    #
    #   # Request: complete example, including address, billing address, shipping address
    #    complete_request_options = {
    #      order_id: "your merchant/shop order id", # alternative is to set merchantInvoiceId
    #      merchant_transaction_id: "your merchant/shop transaction id",
    #      address: address,
    #      description: 'Store Purchase - Books',
    #      risk_workflow: false,
    #      test_mode: 'EXTERNAL' # or 'INTERNAL', valid only for test system
    #      create_registration: false, # payment details will be stored on the server an latter can be referenced
    #
    #     billing_address: {
    #        address1: '123 Test Street',
    #        city:     'Test',
    #        state:    'TE',
    #        zip:      'AB12CD',
    #        country:  'GB',
    #      },
    #      shipping_address: {
    #        name:     'Muton DeMicelis',
    #        address1: 'My Street On Upiter, Apt 3.14/2.78',
    #        city:     'Munich',
    #        state:    'Bov',
    #        zip:      '81675',
    #        country:  'DE',
    #      },
    #      customer: {
    #        merchant_customer_id:  "your merchant/customer id",
    #        givenname:  'Jane',
    #        surname:  'Jones',
    #        birth_date:  '1965-05-01',
    #        phone:  '(?!?)555-5555',
    #        mobile:  '(?!?)234-23423',
    #        email:  'jane@jones.com',
    #        company_name:  'JJ Ltd.',
    #        identification_doctype:  'PASSPORT',
    #        identification_docid:  'FakeID2342431234123',
    #        ip:  101.102.103.104,
    #      },
    #    }
    #
    #    # Request: minimal example
    #    minimal_request_options = {
    #      order_id: "your merchant/shop order id", # alternative is to set merchantInvoiceId
    #      description: 'Store Purchase - Books',
    #    }
    #
    #   options =
    #   # run request
    #   response = gateway.purchase(754, creditcard, options) # charge 7,54 EUR
    #
    #   response.success?                   # Check whether the transaction was successful
    #   response.error_code                 # Retrieve the error message - it's mapped to Gateway::STANDARD_ERROR_CODE
    #   response.message                    # Retrieve the message returned by opp
    #   response.authorization              # Retrieve the unique transaction ID returned by opp
    #   response.params['result']['code']   # Retrieve original return code returned by opp server
    #
    # == Errors
    #   If transaction is not successful, response.error_code contains mapped to Gateway::STANDARD_ERROR_CODE error message.
    #   Complete list of opp error codes can be viewed on https://docs.oppwa.com/
    #   Because this list is much bigger than Gateway::STANDARD_ERROR_CODE, only fraction is mapped to Gateway::STANDARD_ERROR_CODE.
    #   All other codes are mapped as Gateway::STANDARD_ERROR_CODE[:processing_error], so if this is the case,
    #   you may check the original result code from OPP that can be found in response.params['result']['code']
    #
    # == Special features
    #   For purchase method risk check can be forced when options[:risk_workflow] = true
    #   This will split (on OPP server side) the transaction into two separate transactions: authorize and capture,
    #   but capture will be executed only if risk checks are successful.
    #
    #   For testing you may use the test account details listed fixtures.yml under opp. It is important to note that there are two test modes available:
    #     options[:test_mode]='EXTERNAL' causes test transactions to be forwarded to the processor's test system for 'end-to-end' testing
    #     options[:test_mode]='INTERNAL' causes transactions to be sent to opp simulators, which is useful when switching to the live endpoint for connectivity testing.
    #   If no test_mode parameter is sent, test_mode=INTERNAL is the default behaviour.
    #
    #   Billing Address, Shipping Address, Custom Parameters are supported as described under https://docs.oppwa.com/parameters
    #   See complete example above for details.
    #
    #   == Tokenization
    #  When create_registration is set to true, the payment details will be stored and a token will be returned in registrationId response field,
    #  which can subsequently be used to reference the stored payment.

      self.test_url = 'https://test.oppwa.com/v1/payments'
      self.live_url = 'https://oppwa.com/v1/payments'

      self.supported_countries = %w(AD AI AG AR AU AT BS BB BE BZ BM BR BN BG CA HR CY CZ DK DM EE FI FR DE GR GD GY HK HU IS IN IL IT JP LV LI LT LU MY MT MX MC MS NL PA PL PT KN LC MF VC SM SG SK SI ZA ES SR SE CH TR GB US UY)
      self.default_currency = 'EUR'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro, :dankort]

      self.homepage_url = 'https://docs.oppwa.com'
      self.display_name = 'Open Payment Platform'

      def initialize(options={})
        requires!(options, :user_id, :password, :entity_id)
        super
      end

      def purchase(money, payment, options={})
        # debit
        execute_dbpa(options[:risk_workflow] ? 'PA.CP': 'DB',
          money, payment, options)
      end

      def authorize(money, payment, options={})
        # preauthorization PA
        execute_dbpa('PA', money, payment, options)
      end

      def capture(money, authorization, options={})
        # capture CP
        execute_referencing('CP', money, authorization, options)
      end

      def refund(money, authorization, options={})
        # refund RF
        execute_referencing('RF', money, authorization, options)
      end

      def void(authorization, options={})
        # reversal RV
        execute_referencing('RV', nil, authorization, options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((authentication\.password=)\w+), '\1[FILTERED]').
          gsub(%r((card\.number=)\d+), '\1[FILTERED]').
          gsub(%r((card\.cvv=)\d+), '\1[FILTERED]')
      end

      private

      def execute_dbpa(txtype, money, payment, options)
        post = {}
        post[:paymentType] = txtype
        add_invoice(post, money, options)
        add_payment_method(post, payment, options)
        add_address(post, options)
        add_customer_data(post, payment, options)
        add_options(post, options)
        add_3d_secure(post, options)
        commit(post, nil, options)
      end

      def execute_referencing(txtype, money, authorization, options)
        post = {}
        post[:paymentType] = txtype
        add_invoice(post, money, options)
        commit(post, authorization, options)
      end

      def add_authentication(post)
          post[:authentication] = { entityId: @options[:entity_id], password: @options[:password], userId: @options[:user_id]}
      end

      def add_customer_data(post, payment, options)
        if options[:customer]
          post[:customer] = {
            merchantCustomerId:  options[:customer][:merchant_customer_id],
            givenName:  options[:customer][:givenname] || payment.first_name,
            surname:  options[:customer][:surname] || payment.last_name,
            birthDate:  options[:customer][:birth_date],
            phone:  options[:customer][:phone],
            mobile:  options[:customer][:mobile],
            email:  options[:customer][:email] || options[:email],
            companyName:  options[:customer][:company_name],
            identificationDocType:  options[:customer][:identification_doctype],
            identificationDocId:  options[:customer][:identification_docid],
            ip:  options[:customer][:ip] || options[:ip]
          }
        end
      end

      def add_address(post, options)
        if billing_address = options[:billing_address] || options[:address]
          address(post, billing_address, 'billing')
        end
        if shipping_address = options[:shipping_address]
          address(post, shipping_address, 'shipping')
          if shipping_address[:name]
            firstname, lastname = shipping_address[:name].split(' ')
            post[:shipping] = { givenName: firstname, surname: lastname }
          end
        end
      end

      def address(post, address, prefix)
        post[prefix] = {
          street1: address[:address1],
          street2: address[:address2],
          city: address[:city],
          state: address[:state],
          postcode: address[:zip],
          country: address[:country],
        }
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = options[:currency] || currency(money) unless post[:paymentType] == 'RV'
        post[:descriptor] = options[:description] || options[:descriptor]
        post[:merchantInvoiceId] = options[:merchantInvoiceId] || options[:order_id]
        post[:merchantTransactionId] = options[:merchant_transaction_id] || generate_unique_id
      end

      def add_payment_method(post, payment, options)
        if options[:registrationId]
          #post[:recurringType] = 'REPEATED'
          post[:card] = {
            cvv: payment.verification_value,
          }
        else
          post[:paymentBrand] = payment.brand.upcase
          post[:card] = {
            holder: payment.name,
            number: payment.number,
            expiryMonth: "%02d" % payment.month,
            expiryYear: payment.year,
            cvv: payment.verification_value,
          }
        end
      end

      def add_3d_secure(post, options)
        return unless options[:eci] && options[:cavv] && options[:xid]

        post[:threeDSecure] = {
          eci: options[:eci],
          verificationId: options[:cavv],
          xid: options[:xid]
        }
      end

      def add_options(post, options)
        post[:createRegistration] = options[:create_registration] if options[:create_registration] && !options[:registrationId]
        post[:testMode] = options[:test_mode] if test? && options[:test_mode]
        options.each {|key, value| post[key] = value if key.to_s.match('customParameters\[[a-zA-Z0-9\._]{3,64}\]') }
        post['customParameters[SHOPPER_pluginId]'] = 'activemerchant'
        post['customParameters[custom_disable3DSecure]'] = options[:disable_3d_secure] if options[:disable_3d_secure]
      end

      def build_url(url, authorization, options)
        if options[:registrationId]
          "#{url.gsub(/payments/, 'registrations')}/#{options[:registrationId]}/payments"
        elsif authorization
          "#{url}/#{authorization}"
        else
          url
        end
      end

      def commit(post, authorization, options)
        url = build_url(test? ? test_url : live_url, authorization, options)
        add_authentication(post)
        post = flatten_hash(post)

        response = begin
          parse(
            ssl_post(
              url,
              post.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&"),
              "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8"
            )
          )
        rescue ResponseError => e
          parse(e.response.body)
        end

        success = success_from(response)

        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: success ? nil : error_code_from(response),
        )
      end

      def parse(body)
        begin
          JSON.parse(body)
        rescue JSON::ParserError
          json_error(body)
        end
      end

      def json_error(body)
        message = "Invalid response received #{body.inspect}"
        { 'result' => {'description' => message, 'code' => 'unknown' } }
      end

      def success_from(response)
        return false unless response['result']

        success_regex = /^(000\.000\.|000\.100\.1|000\.[36])/

        if success_regex =~ response['result']['code']
          true
        else
          false
        end
      end

      def message_from(response)
        return 'Failed' unless response['result']

        response['result']['description']
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(response)
        response['result']['code']
      end

      def flatten_hash(hash)
        hash.each_with_object({}) do |(k, v), h|
          if v.is_a? Hash
            flatten_hash(v).map do |h_k, h_v|
              h["#{k}.#{h_k}".to_sym] = h_v
            end
          else
            h[k] = v
          end
         end
      end
    end
  end
end
