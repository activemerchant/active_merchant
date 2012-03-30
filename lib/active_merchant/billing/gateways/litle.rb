require 'rubygems'
require 'LitleOnline'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class LitleGateway < Gateway
      #Specific to Litle options:
      # * <tt>:merchant_id</tt> - Merchant Id assigned by Litle
      # * <tt>:user</tt> - Username assigned by Litle
      # * <tt>:password</tt> - Password assigned by Litle
      # * <tt>:version</tt> - The version of the api you are using (eg, '8.10')
      # * <tt>:proxy_addr</tt> - Proxy address - nil if not needed
      # * <tt>:proxy_port</tt> - Proxy port - nil if not needed
      # * <tt>:url</tt> - URL assigned by Litle (for testing, use the sandbox)
      #Standard Active Merchant options
      # * <tt>:order_id</tt> - The order number
      # * <tt>:ip</tt> - The IP address of the customer making the purchase
      # * <tt>:customer</tt> - The name, customer number, or other information that identifies the customer
      # * <tt>:invoice</tt> - The invoice number
      # * <tt>:merchant</tt> - The name or description of the merchant offering the product
      # * <tt>:description</tt> - A description of the transaction
      # * <tt>:email</tt> - The email address of the customer
      # * <tt>:currency</tt> - The currency of the transaction. Only important when you are using a currency that is not the default with a gateway that supports multiple currencies.
      # * <tt>:billing_address</tt> - A hash containing the billing address of the customer.
      # * <tt>:shipping_address</tt> - A hash containing the shipping address of the customer.
      #
      # The <tt>:billing_address</tt>, and <tt>:shipping_address</tt> hashes can have the following keys:
      #
      # * <tt>:name</tt> - The full name of the customer.
      # * <tt>:company</tt> - The company name of the customer.
      # * <tt>:address1</tt> - The primary street address of the customer.
      # * <tt>:address2</tt> - Additional line of address information.
      # * <tt>:city</tt> - The city of the customer.
      # * <tt>:state</tt> - The state of the customer. The 2 digit code for US and Canadian addresses. The full name of the state or province for foreign addresses.
      # * <tt>:country</tt> - The [ISO 3166-1-alpha-2 code](http://www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm) for the customer.
      # * <tt>:zip</tt> - The zip or postal code of the customer.
      # * <tt>:phone</tt> - The phone number of the customer.
      # money (int in cents), creditcard, options = {}
      #
      TEST_URL = 'https://www.testlitle.com/sandbox/communicator/online'
      LIVE_URL = 'https://payments.litle.com/vap/communicator/online'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.litle.com/'

      # The name of the gateway
      self.display_name = 'Litle & Co.'

      self.default_currency = 'USD'

      attr_accessor :order_id

      def initialize
        @litle = LitleOnlineRequest.new
        @order_id = 'undefined'
      end

      def authorize(money, creditcard, options = {})
        to_pass = create_credit_card_hash(money, creditcard, options)
        ret = @litle.authorization(to_pass) # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.authorizationResponse.response == '000'),
          ret.authorizationResponse.message,
          {:litleOnlineResponse=>ret} ,
          {:authorization => ret.authorizationResponse.litleTxnId,
            :avs_result => {:code=>fraud_result(ret.authorizationResponse)['avs']},
            :cvv_result => fraud_result(ret.authorizationResponse)['cvv']
          }
          )
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        resp
      end

      def purchase(money, creditcard, options = {})
        to_pass = create_credit_card_hash(money, creditcard, options)
        ret = @litle.sale(to_pass) # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.saleResponse.response == '000'), ret.saleResponse.message,{:litleOnlineResponse=>ret},
            {
            :avs_result => {:code=>fraud_result(ret.saleResponse)['avs']},
            :cvv_result => fraud_result(ret.saleResponse)['cvv']
          }
          )
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret}
          )
        end
      end

      def capture(money, authorization, options = {})
        to_pass = create_capture_hash(money, authorization, options)
        ret = @litle.capture(to_pass) # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.captureResponse.response == '000'), ret.captureResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        resp
      end

      def void(identification, options = {})
        to_pass = create_void_hash(identification, options)
        ret = @litle.void(to_pass) # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.voidResponse.response == '000'), ret.voidResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        resp
      end

      def credit(money, identification, options = {})
        to_pass = create_credit_hash(money, identification, options)
        ret = @litle.credit(to_pass) # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.creditResponse.response == '000'), ret.creditResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        resp
      end

      def store(creditcard, options = {})
        to_pass = create_token_hash(creditcard, options)
        ret = @litle.register_token_request(to_pass) # passing the hash.
        if ret.response == "0"
          resp = Response.new((ret.registerTokenResponse.response == '801' or ret.registerTokenResponse.response == '802'), ret.registerTokenResponse.message,{:litleOnlineResponse=>ret})
        else
          resp = Response.new((false), ret.message,{:litleOnlineResponse=>ret})
        end
        resp
      end

      private
      CARD_TYPE = {
        'visa' => 'VI',
        'master' => 'MC',
        'american_express' => 'AX',
        'discover' => 'DI',
        'jcb' => 'DI',
        'diners_club' => 'DI'
      }

      AVS_RESPONSE_CODE = {
        '00' => 'Y',
        '01' => 'X',
        '02' => 'D',
        '10' => 'Z',
        '11' => 'W',
        '12' => 'A',
        '13' => 'A',
        '14' => 'P',
        '20' => 'N',
        '30' => 'S',
        '31' => 'R',
        '32' => 'U',
        '33' => 'R',
        '34' => 'I',
        '40' => 'E'
      }

      def create_credit_card_hash(money, creditcard, options)
        cc_type = CARD_TYPE[creditcard.type]

        exp_date_yr = creditcard.year.to_s()[2..3]

        if( creditcard.month.to_s().length == 1 )
          exp_date_mo = '0' + creditcard.month.to_s()
        else
          exp_date_mo = creditcard.month.to_s()
        end

        exp_date = exp_date_mo + exp_date_yr

        card_info = {
          'type' => cc_type,
          'number' => creditcard.number,
          'expDate' => exp_date,
          'cardValidationNum' => creditcard.verification_value
        }

        hash = create_hash(money, options)
        hash['card'] = card_info
        hash
      end

      def create_capture_hash(money, authorization, options)
        hash = create_hash(money, options)
        hash['litleTxnId'] = authorization
        hash
      end

      def create_credit_hash(money, identification, options)
        hash = create_hash(money, options)
        hash['litleTxnId'] = identification
        hash['orderSource'] = nil
        hash['orderId'] = nil
        hash
      end

      def create_token_hash(creditcard, options)
        hash = create_hash(0, options)
        hash['accountNumber'] = creditcard.number
        hash
      end

      def create_void_hash(identification, options)
        hash = create_hash(nil, options)
        hash['litleTxnId'] = identification
        hash
      end

      def create_hash(money, options)
        currency = options[:currency]
        merchant_id = options[:merchant_id]
        user=options[:user]
        password=options[:password]
        version=options[:version]
        url=options[:url]
        fraud_check_type = {}
        if !options[:ip].nil?
          fraud_check_type['customerIpAddress'] = options[:ip]
        end

        enhanced_data = {}
        if !options[:invoice].nil?
          enhanced_data['invoiceReferenceNumber'] = options[:invoice]
        end

        if !options[:description].nil?
          enhanced_data['customerReference'] = options[:description]
        end

        if !options[:billing_address].nil?
          bill_to_address = {
            'name' => options[:billing_address][:name],
            'companyName' => options[:billing_address][:company],
            'addressLine1' => options[:billing_address][:address1],
            'addressLine2' => options[:billing_address][:address2],
            'city' => options[:billing_address][:city],
            'state' => options[:billing_address][:state],
            'zip' => options[:billing_address][:zip],
            'country' => options[:billing_address][:country],
            'email' => options[:email],
            'phone' => options[:billing_address][:phone]
          }
        end
        if !options[:shipping_address].nil?
          ship_to_address = {
            'name' => options[:shipping_address][:name],
            'companyName' => options[:shipping_address][:company],
            'addressLine1' => options[:shipping_address][:address1],
            'addressLine2' => options[:shipping_address][:address2],
            'city' => options[:shipping_address][:city],
            'state' => options[:shipping_address][:state],
            'zip' => options[:shipping_address][:zip],
            'country' => options[:shipping_address][:country],
            'email' => options[:email],
            'phone' => options[:shipping_address][:phone]
          }
        end

        hash = {
          'billToAddress' => bill_to_address,
          'shipToAddress' => ship_to_address,
          'orderId' => (options[:order_id] or @order_id),
          'customerId' => options[:customer],
          'reportGroup' => (options[:merchant] or merchant_id),
          'merchantId' => merchant_id,
          'orderSource' => 'ecommerce',
          'enhancedData' => enhanced_data,
          'fraudCheckType' => fraud_check_type,
          'user' => user,
          'password' => password,
          'version' => version,
          'url' => url,
          'proxy_addr' => options[:proxy_addr],
          'proxy_port' => options[:proxy_port]
        }

        if( !money.nil? && money.to_s.length > 0 )
          hash.merge!({'amount' => money})
        end
        hash
      end

      def fraud_result(authorization_response)
        if authorization_response.respond_to?('fraudResult')
          fraud_result = authorization_response.fraudResult
          if fraud_result.respond_to?('cardValidationResult')
            cvv_to_pass = fraud_result.cardValidationResult
            if(cvv_to_pass == "")
              cvv_to_pass = "P"
            end
          end
          if fraud_result.respond_to?('avsResult')
            avs_to_pass = AVS_RESPONSE_CODE[fraud_result.avsResult]
          end
        end
        {'cvv'=>cvv_to_pass, 'avs'=>avs_to_pass}
      end

    end
  end
end
