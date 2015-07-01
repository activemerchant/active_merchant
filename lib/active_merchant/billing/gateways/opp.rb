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
    #      userId: 'merchant user id', 
    #      password: 'password',
    #      entityId: 'entity id', 
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
    #   # Request: complete example, including address, billing address, shipping address, shopping cart
    #    complete_request_options = {
    #      order_id: "your merchant/shop order id", # alternative is to set merchantInvoiceId 
    #      merchantTransactionId: "your merchant/shop transaction id",
    #      address: address,
    #      description: 'Store Purchase - Books',
    #      riskWorkflow: false,
    #      testMode: 'EXTERNAL' # or 'INTERNAL', valid only for test system
    #      createRegistration: false, # payment details will be stored on the server an latter can be referenced
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
    #        merchantCustomerId:  "your merchant/customer id",
    #        givenName:  'Jane',
    #        surname:  'Jones',
    #        birthDate:  '1965-05-01',
    #        phone:  '(?!?)555-5555',
    #        mobile:  '(?!?)234-23423',
    #        email:  'jane@jones.com',
    #        companyName:  'JJ Ltd.',
    #        identificationDocType:  'PASSPORT',
    #        identificationDocId:  'FakeID2342431234123',
    #        ip:  101.102.103.104,
    #      },
    #      cart: {
    #        items: [
    #            { name: ' Bestseller Book', merchantItemId: 'isbn-0123456789012345', 
    #              quantity: 1, type: 'book', price: 1.95, currency: 'EUR', description: 'Some item description',
    #              tax: 7.0, shipping: 3.25, discount: 5.0
    #            },                    
    #            { name: 'Book 2', merchantItemId: 'isbn-0123456789012345', 
    #              quantity: 1, type: 'book', price: 2.45, currency: 'EUR', description: 'Other item description',
    #              tax: 7.0, shipping: 3.25, discount: 10.0
    #            }                    
    #        ],
    #      },
    #    }
    #    
    #    # Request: minimal example
    #    minimal_request_options = {
    #      order_id: "your merchant/shop order id", # alternative is to set merchantInvoiceId 
    #      merchantTransactionId: "your merchant/shop transaction id",
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
    #   For purchase method risk check can be forced when options[:riskWorkflow] = true 
    #   This will split (on OPP server side) the transaction into two separate transactions: authorize and capture, 
    #   but capture will be executed only if risk checks are successful.   
    #
    #   For testing you may use the test account details listed fixtures.yml under opp. It is important to note that there are two test modes available:
    #     options[:testMode]='EXTERNAL' causes test transactions to be forwarded to the processor's test system for 'end-to-end' testing
    #     options[:testMode]='INTERNAL' causes transactions to be sent to opp simulators, which is useful when switching to the live endpoint for connectivity testing.
    #   If no testMode parameter is sent, testMode=INTERNAL is the default behaviour.
    #
    #   Shopping Cart, Billing Address, Shipping Address, Custom Parameters are supported as described under https://docs.oppwa.com/parameters
    #   See complete example above for details. 
    #
    #   == Tokenization
    #  When createRegistration is set to true, the payment details will be stored and a token will be returned in registrationId response field, 
    #  which can subsequently be used to referenced the stored payment.

      self.test_url = 'https://test.oppwa.com/v1/payments'
      self.live_url = 'https://oppwa.com/v1/payments'

      self.supported_countries = %w(AD AI AG AR AU AT BS BB BE BZ BM BR BN BG CA HR CY CZ DK DM EE FI FR DE GR GD GY HK HU IS IN IL IT JP LV LI LT LU MY MT MX MC MS NL PA PL PT KN LC MF VC SM SG SK SI ZA ES SR SE CH TR GB US UY)
      self.default_currency = 'EUR'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro, :dankort] 

      self.homepage_url = 'https://docs.oppwa.com'
      self.display_name = 'Open Payment Platform'

      METHOD_TO_PAYMENTTYPE_MAPPING = { purchase: 'DB', authorize: 'PA', capture: 'CP', refund: 'RF', void: 'RV', pacp: 'PA.CP' }

      def initialize(options={})
        requires!(options, :userId, :password, :entityId)
        super
      end

      def purchase(money, payment, options={})
        # debit
        execute_dbpa(options[:riskWorkflow] ? METHOD_TO_PAYMENTTYPE_MAPPING[:pacp]: METHOD_TO_PAYMENTTYPE_MAPPING[__method__], 
          money, payment, options)
      end

      def authorize(money, payment, options={})
        # preauthorization PA
        execute_dbpa(METHOD_TO_PAYMENTTYPE_MAPPING[__method__], money, payment, options)
      end
      
      def capture(money, authorization, options={})
        # capture CP
        execute_referencing(METHOD_TO_PAYMENTTYPE_MAPPING[__method__], money, authorization, options)
      end

      def refund(money, authorization, options={})
        # refund RF
        execute_referencing(METHOD_TO_PAYMENTTYPE_MAPPING[__method__], money, authorization, options)
      end

      def void(authorization, options={})
        # reversal RV
        execute_referencing(METHOD_TO_PAYMENTTYPE_MAPPING[__method__], nil, authorization, options)
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
          gsub(%r((authentication\.userId=)\w+), '\1[FILTERED]').
          gsub(%r((authentication\.entityId=)\w+), '\1[FILTERED]').
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
        add_cart_items(post, options)
        add_customer_data(post, options)
        add_options(post, options)
        commit(post, nil, options)
      end

      def execute_referencing(txtype, money, authorization, options)
        post = {}
        post[:paymentType] = txtype
        add_invoice(post, money, options)
        commit(post, authorization, options)
      end

      def add_authentication(post) 
          post[:authentication] = { entityId: @options[:entityId], password: @options[:password], userId: @options[:userId]} 
      end

      def add_customer_data(post, options)
        if options[:customer]
          post[:customer] = {
            merchantCustomerId:  options[:customer][:merchantCustomerId],
            givenName:  options[:customer][:givenName],
            surname:  options[:customer][:surname],
            birthDate:  options[:customer][:birthDate],
            phone:  options[:customer][:phone],
            mobile:  options[:customer][:mobile],
            email:  options[:customer][:email],
            companyName:  options[:customer][:companyName],
            identificationDocType:  options[:customer][:identificationDocType],
            identificationDocId:  options[:customer][:identificationDocId],
            ip:  options[:customer][:ip],
          }
        end
      end

      def add_address(post, options)
        if billing_address = options[:billing_address]
          address(post, billing_address, 'billing')
        end
        if shipping_address = options[:shipping_address]
          address(post, billing_address, 'shipping')
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
          post[:currency] = (currency(money) || @options[:currency]) if 'RV'!=(post[:paymentType])
          post[:descriptor] = options[:description] || options[:descriptor]  
          post[:merchantInvoiceId] = options[:merchantInvoiceId] || options[:order_id] 
          post[:merchantTransactionId] = options[:merchantTransactionId]  
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

      def add_options(post, options)
        post[:createRegistration] = options[:createRegistration] if options[:createRegistration] && !options[:registrationId]
        post[:testMode] = options[:testMode] if test? && options[:testMode]
        options.each {|key, value| post[key] = value if key.to_s.match('customParameters\[[a-zA-Z0-9\._]{3,64}\]') }
        post['customParameters[SHOPPER_pluginId]'] = 'activemerchant'
      end

      def add_cart_items(post, options)
        if cart = options[:cart]
          if cart[:items] 
            post[:cart] = {}
            cart[:items].each_with_index {|value, idx|
              post[:cart]["items[#{idx}]"] = {} 
              post[:cart]["items[#{idx}]"][:name] = value[:name] if value[:name]   
              post[:cart]["items[#{idx}]"][:merchantItemId] = value[:merchantItemId] if value[:merchantItemId]
              post[:cart]["items[#{idx}]"][:quantity] = value[:quantity] if value[:quantity]
              post[:cart]["items[#{idx}]"][:type] = value[:type] if value[:type]
              post[:cart]["items[#{idx}]"][:price] = value[:price] if value[:price]
              post[:cart]["items[#{idx}]"][:currency] = value[:currency] if value[:currency]
              post[:cart]["items[#{idx}]"][:description] = value[:description] if value[:description]
              post[:cart]["items[#{idx}]"][:tax] =  value[:tax] if value[:tax]
              post[:cart]["items[#{idx}]"][:shipping] = value[:shipping] if value[:shipping]
              post[:cart]["items[#{idx}]"][:discount] = value[:discount] if value[:discount]
            }
          end    
        end
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
        url = (test? ? test_url : live_url)
        add_authentication(post)
        post = flatten_hash(post)

        url = build_url(url, authorization, options)
        raw_response = raw_ssl_request(:post, url, 
            post.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&"), 
            "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8")
            
        success = success_from(raw_response)
        response = raw_response.body
        begin 
          response = JSON.parse(response)          
        rescue JSON::ParserError
          response = json_error(response)
        end

        Response.new(
          success,
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: success ? nil : error_code_from(response),
        )
      end

      def success_from(raw_response)
        raw_response.code.to_i.between?(200,299)  
      end

      def message_from(response)
        response['result']['description']
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(response)
          case response['result']['code']
          when '100.100.101' 
              Gateway::STANDARD_ERROR_CODE[:incorrect_number]
          when '100.400.317' 
              Gateway::STANDARD_ERROR_CODE[:invalid_number]
          when '100.100.600', '100.100.601', '800.100.153', '800.100.192' 
              Gateway::STANDARD_ERROR_CODE[:invalid_cvc]
          when '100.100.303' 
              Gateway::STANDARD_ERROR_CODE[:expired_card]
          when '100.800.200', '100.800.201', '100.800.202', '800.800.202' 
              Gateway::STANDARD_ERROR_CODE[:incorrect_zip]
          when '100.400.000', '100.400.086', '100.400.305', '800.400.150' 
              Gateway::STANDARD_ERROR_CODE[:incorrect_address]
          when '800.100.159' 
              Gateway::STANDARD_ERROR_CODE[:pickup_card]
          when '800.100.151', '800.100.158', '800.100.160' 
              Gateway::STANDARD_ERROR_CODE[:card_declined]
            else
              Gateway::STANDARD_ERROR_CODE[:processing_error]
          end
      end
      
      def json_error(raw_response)
        message = "Invalid response received #{raw_response.inspect}"
        { 'result' => {'description' => message, 'code' => 'unknown' } }
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
