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

      LITLE_SCHEMA_VERSION     = '8.13'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      # The homepage URL of the gateway
      self.homepage_url        = 'http://www.litle.com/'

      # The name of the gateway
      self.display_name        = 'Litle & Co.'

      self.default_currency = 'USD'

      def initialize(options = {})
        begin
          require 'LitleOnline'
        rescue LoadError
          raise "Could not load the LitleOnline gem (> 08.15.0).  Use `gem install LitleOnline` to install it."
        end

        if wiredump_device
          LitleOnline::Configuration.logger = ((Logger === wiredump_device) ? wiredump_device : Logger.new(wiredump_device))
          LitleOnline::Configuration.logger.level = Logger::DEBUG
        else
          LitleOnline::Configuration.logger = Logger.new(STDOUT)
          LitleOnline::Configuration.logger.level = Logger::WARN
        end

        @litle = LitleOnline::LitleOnlineRequest.new

        options[:version]  ||= LITLE_SCHEMA_VERSION
        options[:merchant] ||= 'Default Report Group'
        options[:user]     ||= options[:login]

        requires!(options, :merchant_id, :user, :password, :merchant, :version)

        super
      end

      def authorize(money, creditcard_or_token, options = {})
        to_pass = build_authorize_request(money, creditcard_or_token, options)
        build_response(:authorization, @litle.authorization(to_pass))
      end

      def purchase(money, creditcard_or_token, options = {})
        to_pass = build_purchase_request(money, creditcard_or_token, options)
        build_response(:sale, @litle.sale(to_pass))
      end

      def capture(money, authorization, options = {})
        transaction_id, kind = split_authorization(authorization)
        to_pass = create_capture_hash(money, transaction_id, options)
        build_response(:capture, @litle.capture(to_pass))
      end

      # Note: Litle requires that authorization requests be voided via auth_reversal
      # and other requests via void. To maintain the same interface as the other
      # gateways the transaction_id and the kind of transaction are concatenated
      # together with a ; separator (e.g. 1234;authorization)
      #
      # A partial auth_reversal can be accomplished by passing :amount as an option
      def void(identification, options = {})
        transaction_id, kind = split_authorization(identification)
        if(kind == 'authorization')
          to_pass = create_auth_reversal_hash(transaction_id, options[:amount], options)
          build_response(:authReversal, @litle.auth_reversal(to_pass))
        else
          to_pass = create_void_hash(transaction_id, options)
          build_response(:void, @litle.void(to_pass))
        end
      end

      def refund(money, authorization, options = {})
        to_pass = build_credit_request(money, authorization, options)
        build_response(:credit, @litle.credit(to_pass))
      end

      def credit(money, authorization, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def store(creditcard_or_paypage_registration_id, options = {})
        to_pass = create_token_hash(creditcard_or_paypage_registration_id, options)
        build_response(:registerToken, @litle.register_token_request(to_pass), %w(000 801 802))
      end

      private

      CARD_TYPE = {
          'visa'             => 'VI',
          'master'           => 'MC',
          'american_express' => 'AX',
          'discover'         => 'DI',
          'jcb'              => 'DI',
          'diners_club'      => 'DI'
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
          detail        = response["#{kind}Response"]
          fraud         = fraud_result(detail)
          Response.new(
              valid_responses.include?(detail['response']),
              detail['message'],
              { :litleOnlineResponse => response },
              :authorization => authorization_from(detail, kind),
              :avs_result    => { :code => fraud['avs'] },
              :cvv_result    => fraud['cvv'],
              :test          => test?
          )
        else
          Response.new(false, response['message'], :litleOnlineResponse => response, :test => test?)
        end
      end

      # Generates an authorization string of the appropriate id and the kind of transaction
      # See #void for how the kind is used
      def authorization_from(litle_response, kind)
        case kind
        when :registerToken
          authorization = litle_response['litleToken']
        else
          authorization = [litle_response['litleTxnId'], kind.to_s].join(";")
        end
      end

      def split_authorization(authorization)
        transaction_id, kind = authorization.to_s.split(';')
        [transaction_id, kind]
      end

      def build_authorize_request(money, creditcard_or_token, options)
        payment_method = build_payment_method(creditcard_or_token, options)

        hash = create_hash(money, options)

        add_creditcard_or_cardtoken_hash(hash, payment_method)

        hash
      end

      def build_purchase_request(money, creditcard_or_token, options)
        payment_method = build_payment_method(creditcard_or_token, options)

        hash = create_hash(money, options)

        add_creditcard_or_cardtoken_hash(hash, payment_method)

        hash
      end

      def build_credit_request(money, identification_or_token, options)
        payment_method = build_payment_method(identification_or_token, options)

        hash = create_hash(money, options)

        add_identification_or_cardtoken_hash(hash, payment_method)

        unless payment_method.is_a?(LitleCardToken)
          hash['orderSource'] = nil
          hash['orderId']     = nil
        end

        hash
      end

      def build_payment_method(payment_method, options)
        result = payment_method

        # Build instance of the LitleCardToken class for internal use if this is a token request.
        if payment_method.is_a?(String) && options.has_key?(:token)
          result                    = LitleCardToken.new(:token => payment_method)
          result.month              = options[:token][:month]
          result.year               = options[:token][:year]
          result.verification_value = options[:token][:verification_value]
          result.brand              = options[:token][:brand]
        end

        result
      end

      def add_creditcard_or_cardtoken_hash(hash, creditcard_or_cardtoken)
        if creditcard_or_cardtoken.is_a?(LitleCardToken)
          add_cardtoken_hash(hash, creditcard_or_cardtoken)
        else
          add_creditcard_hash(hash, creditcard_or_cardtoken)
        end
      end

      def add_identification_or_cardtoken_hash(hash, identification_or_cardtoken)
        if identification_or_cardtoken.is_a?(LitleCardToken)
          add_cardtoken_hash(hash, identification_or_cardtoken)
        else
          transaction_id, kind = split_authorization(identification_or_cardtoken)
          hash['litleTxnId'] = transaction_id
        end
      end

      def add_cardtoken_hash(hash, cardtoken)
        token_info               = {}
        token_info['litleToken'] = cardtoken.token
        token_info['expDate'] = cardtoken.exp_date if cardtoken.exp_date?
        token_info['cardValidationNum'] = cardtoken.verification_value unless cardtoken.verification_value.blank?
        token_info['type'] = cardtoken.type unless cardtoken.type.blank?

        hash['token'] = token_info
        hash
      end

      def add_creditcard_hash(hash, creditcard)
        cc_type     = CARD_TYPE[creditcard.brand]
        exp_date_yr = creditcard.year.to_s[2..3]
        exp_date_mo = '%02d' % creditcard.month.to_i
        exp_date    = exp_date_mo + exp_date_yr

        card_info = {
            'type'              => cc_type,
            'number'            => creditcard.number,
            'expDate'           => exp_date,
            'cardValidationNum' => creditcard.verification_value
        }

        hash['card'] = card_info
        hash
      end

      def create_capture_hash(money, authorization, options)
        hash               = create_hash(money, options)
        hash['litleTxnId'] = authorization
        hash
      end

      def create_token_hash(creditcard_or_paypage_registration_id, options)
        hash                  = create_hash(0, options)

        if creditcard_or_paypage_registration_id.is_a?(String)
          hash['paypageRegistrationId'] = creditcard_or_paypage_registration_id
        else
          hash['accountNumber'] = creditcard_or_paypage_registration_id.number
        end

        hash
      end

      def create_void_hash(identification, options)
        hash               = create_hash(nil, options)
        hash['litleTxnId'] = identification
        hash
      end

      def create_auth_reversal_hash(identification, money, options)
        hash               = create_hash(money, options)
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
              'name'         => options[:billing_address][:name],
              'companyName'  => options[:billing_address][:company],
              'addressLine1' => options[:billing_address][:address1],
              'addressLine2' => options[:billing_address][:address2],
              'city'         => options[:billing_address][:city],
              'state'        => options[:billing_address][:state],
              'zip'          => options[:billing_address][:zip],
              'country'      => options[:billing_address][:country],
              'email'        => options[:email],
              'phone'        => options[:billing_address][:phone]
          }
        end
        if options[:shipping_address]
          ship_to_address = {
              'name'         => options[:shipping_address][:name],
              'companyName'  => options[:shipping_address][:company],
              'addressLine1' => options[:shipping_address][:address1],
              'addressLine2' => options[:shipping_address][:address2],
              'city'         => options[:shipping_address][:city],
              'state'        => options[:shipping_address][:state],
              'zip'          => options[:shipping_address][:zip],
              'country'      => options[:shipping_address][:country],
              'email'        => options[:email],
              'phone'        => options[:shipping_address][:phone]
          }
        end

        hash = {
            'billToAddress'  => bill_to_address,
            'shipToAddress'  => ship_to_address,
            'orderId'        => (options[:order_id] || @options[:order_id]),
            'customerId'     => options[:customer],
            'reportGroup'    => (options[:merchant] || @options[:merchant]),
            'merchantId'     => (options[:merchant_id] || @options[:merchant_id]),
            'orderSource'    => (options[:order_source] || 'ecommerce'),
            'enhancedData'   => enhanced_data,
            'fraudCheckType' => fraud_check_type,
            'user'           => (options[:user] || @options[:user]),
            'password'       => (options[:password] || @options[:password]),
            'version'        => (options[:version] || @options[:version]),
            'url'            => (options[:url] || url),
            'proxy_addr'     => (options[:proxy_addr] || @options[:proxy_addr]),
            'proxy_port'     => (options[:proxy_port] || @options[:proxy_port]),
            'id'             => (options[:id] || options[:order_id] || @options[:order_id])
        }

        if (!money.nil? && money.to_s.length > 0)
          hash.merge!({ 'amount' => money })
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
        { 'cvv' => cvv_to_pass, 'avs' => avs_to_pass }
      end

      # A +LitleCardToken+ object represents a tokenized credit card, and is capable of validating the various
      # data associated with these.
      #
      # == Example Usage
      #   token = LitleCardToken.new(
      #     :token              => '1234567890123456',
      #     :month              => '9',
      #     :year               => '2010',
      #     :brand              => 'visa',
      #     :verification_value => '123'
      #   )
      #
      #   token.valid? # => true
      #   cc.exp_date # => 0910
      #
      class LitleCardToken
        include Validateable

        # Returns or sets the token. (required)
        #
        # @return [String]
        attr_accessor :token

        # Returns or sets the expiry month for the card associated with token. (optional)
        #
        # @return [Integer]
        attr_accessor :month

        # Returns or sets the expiry year for the card associated with token. (optional)
        #
        # @return [Integer]
        attr_accessor :year

        # Returns or sets the card verification value. (optional)
        #
        # @return [String] the verification value
        attr_accessor :verification_value

        # Returns or sets the credit card brand. (optional)
        #
        # Valid card types are
        #
        # * +'visa'+
        # * +'master'+
        # * +'discover'+
        # * +'american_express'+
        # * +'diners_club'+
        # * +'jcb'+
        # * +'switch'+
        # * +'solo'+
        # * +'dankort'+
        # * +'maestro'+
        # * +'forbrugsforeningen'+
        # * +'laser'+
        #
        # @return (String) the credit card brand
        attr_accessor :brand

        # Returns the Litle credit card type identifier.
        #
        # @return (String) the credit card type identifier
        def type
          CARD_TYPE[brand] unless brand.blank?
        end

        # Returns true if the expiration date is set.
        #
        # @return (Boolean)
        def exp_date?
          !month.to_i.zero? && !year.to_i.zero?
        end

        # Returns the card token expiration date in MMYY format.
        #
        # @return (String) the expiration date in MMYY format
        def exp_date
          result = ''
          if exp_date?
            exp_date_yr = year.to_s[2..3]
            exp_date_mo = '%02d' % month.to_i

            result = exp_date_mo + exp_date_yr
          end
          result
        end

        # Validates the card token details.
        #
        # Any validation errors are added to the {#errors} attribute.
        def validate
          validate_card_token
          validate_expiration_date
          validate_card_brand
        end

        def check?
          false
        end

        private

        CARD_TYPE = {
            'visa'             => 'VI',
            'master'           => 'MC',
            'american_express' => 'AX',
            'discover'         => 'DI',
            'jcb'              => 'DI',
            'diners_club'      => 'DI'
        }

        def before_validate #:nodoc:
          self.month = month.to_i
          self.year  = year.to_i
        end

        # Litle XML Reference Guide 1.8.2
        #
        # The length of the original card number is reflected in the token, so a
        # submitted 16-digit number results in a 16-digit token. Also, all tokens
        # use only numeric characters, so you do not have to change your
        # systems to accept alpha-numeric characters.
        #
        # The credit card token numbers themselves have two parts.
        # The last four digits match the last four digits of the card number.
        # The remaining digits (length can vary based upon original card number
        # length) are a randomly generated.
        def validate_card_token #:nodoc:
          if token.to_s.length < 12 || token.to_s.match(/\A\d+\Z/).nil?
            errors.add :token, "is not a valid card token"
          end
        end

        def validate_expiration_date #:nodoc:
          if !month.to_i.zero? || !year.to_i.zero?
            errors.add :month, "is not a valid month" unless valid_month?(month)
            errors.add :year, "is not a valid year" unless valid_expiry_year?(year)
          end
        end

        def validate_card_brand #:nodoc:
          errors.add :brand, "is invalid" unless brand.blank? || CreditCard.card_companies.keys.include?(brand)
        end

        def valid_month?(month)
          (1..12).include?(month.to_i)
        end

        def valid_expiry_year?(year)
          year.to_s =~ /\A\d{4}\Z/ && year.to_i > 1987
        end
      end
    end
  end
end
