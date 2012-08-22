module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class LitleGateway < Gateway
      # Specific to Litle options:
      # * <tt>:merchant_id</tt> - Merchant Id assigned by Litle
      # * <tt>:user</tt> - Username assigned by Litle
      # * <tt>:password</tt> - Password assigned by Litle
      # * <tt>:version</tt> - The version of the api you are using (eg, '8.10')
      # * <tt>:proxy_addr</tt> - Proxy address - nil if not needed
      # * <tt>:proxy_port</tt> - Proxy port - nil if not needed
      # * <tt>:url</tt> - URL assigned by Litle (for testing, use the sandbox)
      #
      # Standard Active Merchant options
      # * <tt>:order_id</tt> - The order number
      # * <tt>:ip</tt> - The IP address of the customer making the purchase
      # * <tt>:customer</tt> - The name, customer number, or other information that identifies the customer
      # * <tt>:invoice</tt> - The invoice number
      # * <tt>:merchant</tt> - The name or description of the merchant offering the product
      # * <tt>:description</tt> - A description of the transaction
      # * <tt>:email</tt> - The email address of the customer
      # * <tt>:currency</tt> - The currency of the transaction.  Only important when you are using a currency that is not the default with a gateway that supports multiple currencies.
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
      # * <tt>:state</tt> - The state of the customer.  The 2 digit code for US and Canadian addresses. The full name of the state or province for foreign addresses.
      # * <tt>:country</tt> - The [ISO 3166-1-alpha-2 code](http://www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm) for the customer.
      # * <tt>:zip</tt> - The zip or postal code of the customer.
      # * <tt>:phone</tt> - The phone number of the customer.

      self.test_url = 'https://www.testlitle.com/sandbox/communicator/online'
      self.live_url = 'https://payments.litle.com/vap/communicator/online'

      LITLE_SCHEMA_VERSION = '8.10'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.litle.com/'

      # The name of the gateway
      self.display_name = 'Litle & Co.'

      self.default_currency = 'USD'

      def initialize(options = {})
        begin
          require 'LitleOnline'
        rescue LoadError
          raise "Could not load the LitleOnline gem (>= 08.13.2).  Use `gem install LitleOnline` to install it."
        end

        @litle = LitleOnline::LitleOnlineRequest.new

        options[:version]  ||= LITLE_SCHEMA_VERSION
        options[:merchant] ||= 'Default Report Group'
        options[:user]     ||= options[:login]

        requires!(options, :merchant_id, :user, :password, :merchant, :version)

        @options = options
      end

      def authorize(money, creditcard, options = {})
        to_pass = create_credit_card_hash(money, creditcard, options)
        build_response(:authorization, @litle.authorization(to_pass))
      end

      def purchase(money, creditcard, options = {})
        to_pass = create_credit_card_hash(money, creditcard, options)
        build_response(:sale, @litle.sale(to_pass))
      end

      def capture(money, authorization, options = {})
        to_pass = create_capture_hash(money, authorization, options)
        build_response(:capture, @litle.capture(to_pass))
      end

      def void(identification, options = {})
        to_pass = create_void_hash(identification, options)
        build_response(:void, @litle.void(to_pass))
      end

      def credit(money, identification, options = {})
        to_pass = create_credit_hash(money, identification, options)
        build_response(:credit, @litle.credit(to_pass))
      end

      def store(creditcard, options = {})
        to_pass = create_token_hash(creditcard, options)
        build_response(:registerToken, @litle.register_token_request(to_pass), %w(801 802))
      end

      def test?
        super || @options[:test]
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

      def url
        return @options[:url] if @options[:url].present?

        test? ? self.test_url : self.live_url
      end

      def build_response(kind, litle_response, valid_responses=%w(000))
        response = Hash.from_xml(litle_response.raw_xml.to_s)['litleOnlineResponse']

        if response['response'] == "0"
          detail = response["#{kind}Response"]
          fraud = fraud_result(detail)
          Response.new(
            valid_responses.include?(detail['response']),
            detail['message'],
            {:litleOnlineResponse => response},
            :authorization => detail['litleTxnId'],
            :avs_result => {:code => fraud['avs']},
            :cvv_result => fraud['cvv'],
            :test => test?
          )
        else
          Response.new(false, response['message'], :litleOnlineResponse => response, :test => test?)
        end
      end

      def create_credit_card_hash(money, creditcard, options)
        cc_type = CARD_TYPE[creditcard.brand]

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
        fraud_check_type = {}
        if options[:ip]
          fraud_check_type['customerIpAddress'] = options[:ip]
        end

        enhanced_data = {}
        if options[:invoice]
          enhanced_data['invoiceReferenceNumber'] = options[:invoice]
        end

        if options[:description]
          enhanced_data['customerReference'] = options[:description]
        end

        if options[:billing_address]
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
        if options[:shipping_address]
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
          'orderId' => (options[:order_id] || @options[:order_id]),
          'customerId' => options[:customer],
          'reportGroup' => (options[:merchant] || @options[:merchant]),
          'merchantId' => (options[:merchant_id] || @options[:merchant_id]),
          'orderSource' => 'ecommerce',
          'enhancedData' => enhanced_data,
          'fraudCheckType' => fraud_check_type,
          'user' => (options[:user] || @options[:user]),
          'password' => (options[:password] || @options[:password]),
          'version' => (options[:version] || @options[:version]),
          'url' => (options[:url] || url),
          'proxy_addr' => (options[:proxy_addr] || @options[:proxy_addr]),
          'proxy_port' => (options[:proxy_port] || @options[:proxy_port]),
          'id' => (options[:id] || options[:order_id] || @options[:order_id])
        }

        if( !money.nil? && money.to_s.length > 0 )
          hash.merge!({'amount' => money})
        end
        hash
      end

      def fraud_result(authorization_response)
        if result = authorization_response['fraudResult']
          if result.key?('cardValidationResult')
            cvv_to_pass = result['cardValidationResult'].blank? ? "P" : result['cardValidationResult']
          end

          avs_to_pass = AVS_RESPONSE_CODE[result['avsResult']] unless result['avsResult'].blank?
        end
        {'cvv'=>cvv_to_pass, 'avs'=>avs_to_pass}
      end
    end
  end
end
