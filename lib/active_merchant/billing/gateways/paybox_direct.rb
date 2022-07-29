module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayboxDirectGateway < Gateway
      class_attribute :live_url_backup

      self.test_url   = 'https://preprod-ppps.paybox.com/PPPS.php'
      self.live_url   = 'https://ppps.paybox.com/PPPS.php'
      self.live_url_backup = 'https://ppps1.paybox.com/PPPS.php'

      # Payment API Version
      API_VERSION = '00103'

      # Transactions hash
      TRANSACTIONS = {
        authorization: '00001',
        capture: '00002',
        purchase: '00003',
        unreferenced_credit: '00004',
        void: '00005',
        refund: '00014'
      }

      CURRENCY_CODES = {
        'AUD' => '036',
        'CAD' => '124',
        'CZK' => '203',
        'DKK' => '208',
        'HKD' => '344',
        'ICK' => '352',
        'JPY' => '392',
        'NOK' => '578',
        'SGD' => '702',
        'SEK' => '752',
        'CHF' => '756',
        'GBP' => '826',
        'USD' => '840',
        'EUR' => '978',
        'XPF' => '953'
      }

      SUCCESS_CODES = ['00000']
      UNAVAILABILITY_CODES = %w[00001 00097 00098]
      SUCCESS_MESSAGE = 'The transaction was approved'
      FAILURE_MESSAGE = 'The transaction failed'

      # Money is referenced in cents
      self.money_format = :cents
      self.default_currency = 'EUR'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['FR']

      # The card types supported by the payment gateway
      self.supported_cardtypes = %i[visa master american_express diners_club jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.paybox.com/'

      # The name of the gateway
      self.display_name = 'Paybox Direct'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def add_3dsecure(post, options)
        # ECI=02 => MasterCard success
        # ECI=05 => Visa, Amex or JCB success
        if options[:three_d_secure][:eci] == '02' || options[:three_d_secure][:eci] == '05'
          post[:"3DSTATUS"] = 'Y'
          post[:"3DENROLLED"] = 'Y'
          post[:"3DSIGNVAL"] = 'Y'
          post[:"3DERROR"] = '0'
        else
          post[:"3DSTATUS"] = 'N'
          post[:"3DENROLLED"] = 'N'
          post[:"3DSIGNVAL"] = 'N'
          post[:"3DERROR"] = '10000'
        end
        post[:"3DECI"] = options[:three_d_secure][:eci]
        post[:"3DXID"] = options[:three_d_secure][:xid]
        post[:"3DCAVV"] = options[:three_d_secure][:cavv]
        post[:"3DCAVVALGO"] = options[:three_d_secure][:cavv_algorithm]

        # 3DSV2 specific fields
        if options[:three_d_secure][:version]&.start_with?('2')
          billing_address = options[:billing_address] || options[:address]
          shipping_address = options[:shipping_address] || options[:address]

          post[:"3DSTATUS"] = options[:three_d_secure][:authentication_response_status]
          post[:"3DENROLLED"] = 'Y'

          post[:"VERSION3DS"] = options[:three_d_secure][:version]
          post[:"ADRESSEPORTEUR"] = billing_address[:address1] || 'NA'
          post[:"CODEPOSTALPORTEUR"] = billing_address[:zip] if billing_address[:zip]
          post[:"ADRESSELIVRAISON"] = shipping_address[:address1] || 'NA'
          post[:"CODEPOSTALLIVRAISON"] = shipping_address[:zip] if shipping_address[:zip]
          post[:"PAYSLIVRAISON"] = shipping_address[:country] if shipping_address[:country]
          # Browser-based payment = 01
          post[:"TYPOLOGIETRANS3DS"] = '01'
          post[:"DSTRANSID"] = options[:three_d_secure][:ds_transaction_id]
          post[:"ACSTRANSID"] = options[:three_d_secure][:acs_transaction_id]
          post[:"NOMMARCHANDAUTHENT"] = options[:merchant_name] if options[:merchant_name]
          post[:"ADRESSEIPAUTHENT"] = options[:ip] if options[:ip]
          # Frictionless delegated
          post[:"TYPEAUTH3DS"] = 'FD'
          # No preference regarding auth requirement
          post[:"SOUHAITAUTH3DS"] = '01'
          # VADS 3DS proof = 01
          post[:"TYPEPREUVE3DS"] = '01'

          if (options[:"SHOPPINGCART"])
            post[:"SHOPPINGCART"] = options[:"SHOPPINGCART"]
          else
            if (options[:line_items])
                xml = Builder::XmlMarkup.new indent: 0
                xml.instruct!(:xml, version: '1.0', encoding: 'utf-8')
                totalQuantity = 0
                options[:line_items].each do |value|
                totalQuantity += value[:quantity]
                end
                totalQuantity = [[1, totalQuantity].max, 99].min
                xml.tag! 'shoppingcart' do
                    xml.tag! 'total' do
                        xml.tag! 'totalQuantity', totalQuantity
                    end
                end
                xml = xml.target!
                post[:"SHOPPINGCART"] = xml
                post[:"NBARTICLES"] = totalQuantity
            end
          end
        end
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_3dsecure(post, options) if options[:three_d_secure]
        add_amount(post, money, options)
        post[:ERRORCODETEST] = options[:ERRORCODETEST] if options[:ERRORCODETEST]

        commit('authorization', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_3dsecure(post, options) if options[:three_d_secure]
        add_amount(post, money, options)
        post[:ERRORCODETEST] = options[:ERRORCODETEST] if options[:ERRORCODETEST]

        commit('purchase', money, post)
      end

      def capture(money, authorization, options = {})
        requires!(options, :order_id)
        post = {}
        add_invoice(post, options)
        add_amount(post, money, options)
        post[:numappel] = authorization[0, 10]
        post[:numtrans] = authorization[10, 10]

        commit('capture', money, post)
      end

      def void(identification, options = {})
        requires!(options, :order_id, :amount)
        post = {}
        add_invoice(post, options)
        add_reference(post, identification)
        add_amount(post, options[:amount], options)
        post[:porteur] = '000000000000000'
        post[:dateval] = '0000'

        commit('void', options[:amount], post)
      end

      def credit(money, identification, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      def refund(money, identification, options = {})
        post = {}
        add_invoice(post, options)
        add_reference(post, identification)
        add_amount(post, money, options)
        commit('refund', money, post)
      end

      private

      def add_invoice(post, options)
        post[:reference] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:porteur] = creditcard.number
        post[:dateval] = expdate(creditcard)
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
      end

      def add_reference(post, identification)
        post[:numappel] = identification[0, 10]
        post[:numtrans] = identification[10, 10]
      end

      def add_amount(post, money, options)
        post[:montant] = ('0000000000' + (money ? amount(money) : ''))[-10..-1]
        post[:devise] = CURRENCY_CODES[options[:currency] || currency(money)]
      end

      def parse(body)
        results = {}
        body.split(/&/).each do |pair|
          key, val = pair.split(/\=/)
          results[key.downcase.to_sym] = CGI.unescape(val) if val
        end
        results
      end

      def commit(action, money = nil, parameters = nil)
        request_data = post_data(action, parameters)
        response = parse(ssl_post(test? ? self.test_url : self.live_url, request_data))
        response = parse(ssl_post(self.live_url_backup, request_data)) if service_unavailable?(response) && !test?
        Response.new(
          success?(response),
          message_from(response),
          response.merge(timestamp: parameters[:dateq]),
          test: test?,
          authorization: response[:numappel].to_s + response[:numtrans].to_s,
          fraud_review: false,
          sent_params: parameters.delete_if { |key, _value| %w[porteur dateval cvv].include?(key.to_s) }
        )
      end

      def success?(response)
        SUCCESS_CODES.include?(response[:codereponse])
      end

      def service_unavailable?(response)
        UNAVAILABILITY_CODES.include?(response[:codereponse])
      end

      def message_from(response)
        success?(response) ? SUCCESS_MESSAGE : (response[:commentaire] || FAILURE_MESSAGE)
      end

      def post_data(action, parameters = {})
        parameters.update(
          version: API_VERSION,
          type: TRANSACTIONS[action.to_sym],
          dateq: Time.now.strftime('%d%m%Y%H%M%S'),
          numquestion: unique_id(parameters[:order_id]),
          site: @options[:login].to_s[0, 7],
          rang: @options[:rang] || @options[:login].to_s[7..-1],
          cle: @options[:password],
          pays: '',
          archivage: parameters[:order_id]
        )

        parameters.collect { |key, value| "#{key.to_s.upcase}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      def unique_id(seed = 0)
        randkey = "#{seed}#{Time.now.usec}".to_i % 2147483647 # Max paybox value for the question number

        "0000000000#{randkey}"[-10..-1]
      end
    end
  end
end
