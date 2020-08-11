module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SagePayGateway < Gateway
      cattr_accessor :simulate
      self.simulate = false

      class_attribute :simulator_url

      self.test_url = 'https://test.sagepay.com/gateway/service'
      self.live_url = 'https://live.sagepay.com/gateway/service'
      self.simulator_url = 'https://test.sagepay.com/Simulator'

      APPROVED = 'OK'

      TRANSACTIONS = {
        purchase: 'PAYMENT',
        credit: 'REFUND',
        authorization: 'DEFERRED',
        capture: 'RELEASE',
        void: 'VOID',
        abort: 'ABORT',
        store: 'TOKEN',
        unstore: 'REMOVETOKEN',
        repeat: 'REPEAT'
      }

      CREDIT_CARDS = {
        visa: 'VISA',
        master: 'MC',
        delta: 'DELTA',
        maestro: 'MAESTRO',
        american_express: 'AMEX',
        electron: 'UKE',
        diners_club: 'DC',
        jcb: 'JCB'
      }

      AVS_CODE = {
        'NOTPROVIDED' => nil,
        'NOTCHECKED' => 'X',
        'MATCHED' => 'Y',
        'NOTMATCHED' => 'N'
      }

      CVV_CODE = {
        'NOTPROVIDED' => 'S',
        'NOTCHECKED' => 'X',
        'MATCHED' => 'M',
        'NOTMATCHED' => 'N'
      }

      OPTIONAL_REQUEST_FIELDS = {
        paypal_callback_url: :PayPalCallbackURL,
        basket: :Basket,
        gift_aid_payment: :GiftAidPayment,
        apply_avscv2: :ApplyAVSCV2,
        apply_3d_secure: :Apply3DSecure,
        account_type: :AccountType,
        billing_agreement: :BillingAgreement,
        basket_xml: :BasketXML,
        customer_xml: :CustomerXML,
        surcharge_xml: :SurchargeXML,
        vendor_data: :VendorData,
        language: :Language,
        website: :Website,
        recipient_account_number: :FIRecipientAcctNumber,
        recipient_surname: :FIRecipientSurname,
        recipient_postcode: :FIRecipientPostcode,
        recipient_dob: :FIRecipientDoB
      }

      self.supported_countries = %w[GB IE]
      self.supported_cardtypes = %i[visa master american_express discover jcb maestro diners_club]
      self.default_currency = 'GBP'

      self.homepage_url = 'http://www.sagepay.com'
      self.display_name = 'SagePay'

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def purchase(money, payment_method, options = {})
        requires!(options, :order_id)

        post = {}

        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_optional_data(post, options)

        commit((past_purchase_reference?(payment_method) ? :repeat : :purchase), post)
      end

      def authorize(money, payment_method, options = {})
        requires!(options, :order_id)

        post = {}

        add_amount(post, money, options)
        add_invoice(post, options)
        add_payment_method(post, payment_method, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_optional_data(post, options)

        commit(:authorization, post)
      end

      # You can only capture a transaction once, even if you didn't capture the full amount the first time.
      def capture(money, identification, options = {})
        post = {}

        add_reference(post, identification)
        add_release_amount(post, money, options)

        commit(:capture, post)
      end

      def void(identification, options = {})
        post = {}

        add_reference(post, identification)
        action = abort_or_void_from(identification)

        commit(action, post)
      end

      # Refunding requires a new order_id to passed in, as well as a description
      def refund(money, identification, options = {})
        requires!(options, :order_id, :description)

        post = {}

        add_related_reference(post, identification)
        add_amount(post, money, options)
        add_invoice(post, options)

        commit(:credit, post)
      end

      def credit(money, identification, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      def store(credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_currency(post, 0, options)

        commit(:store, post)
      end

      def unstore(token, options = {})
        post = {}
        add_token(post, token)
        commit(:unstore, post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((&?CardNumber=)\d+(&?)), '\1[FILTERED]\2').
          gsub(%r((&?CV2=)\d+(&?)), '\1[FILTERED]\2')
      end

      private

      def truncate(value, max_size)
        return nil unless value
        return value.to_s if CGI.escape(value.to_s).length <= max_size

        if value.size > max_size
          truncate(super(value, max_size), max_size)
        else
          truncate(value.to_s.chop, max_size)
        end
      end

      def add_reference(post, identification)
        order_id, transaction_id, authorization, security_key = identification.split(';')

        add_pair(post, :VendorTxCode, order_id)
        add_pair(post, :VPSTxId, transaction_id)
        add_pair(post, :TxAuthNo, authorization)
        add_pair(post, :SecurityKey, security_key)
      end

      def add_related_reference(post, identification)
        order_id, transaction_id, authorization, security_key = identification.split(';')

        add_pair(post, :RelatedVendorTxCode, order_id)
        add_pair(post, :RelatedVPSTxId, transaction_id)
        add_pair(post, :RelatedTxAuthNo, authorization)
        add_pair(post, :RelatedSecurityKey, security_key)
      end

      def add_amount(post, money, options)
        currency = options[:currency] || currency(money)
        add_pair(post, :Amount, localized_amount(money, currency), required: true)
        add_pair(post, :Currency, currency, required: true)
      end

      def add_currency(post, money, options)
        currency = options[:currency] || currency(money)
        add_pair(post, :Currency, currency, required: true)
      end

      # doesn't actually use the currency -- dodgy!
      def add_release_amount(post, money, options)
        add_pair(post, :ReleaseAmount, amount(money), required: true)
      end

      def add_customer_data(post, options)
        add_pair(post, :CustomerEMail, truncate(options[:email], 255)) unless options[:email].blank?
        add_pair(post, :ClientIPAddress, options[:ip])
      end

      def add_optional_data(post, options)
        add_pair(post, :CreateToken, 1) unless options[:store].blank?

        OPTIONAL_REQUEST_FIELDS.each do |gateway_option, sagepay_field|
          add_pair(post, sagepay_field, options[gateway_option])
        end
      end

      def add_address(post, options)
        if billing_address = options[:billing_address] || options[:address]
          first_name, last_name = split_names(billing_address[:name])
          add_pair(post, :BillingSurname, truncate(last_name, 20))
          add_pair(post, :BillingFirstnames, truncate(first_name, 20))
          add_pair(post, :BillingAddress1, truncate(billing_address[:address1], 100))
          add_pair(post, :BillingAddress2, truncate(billing_address[:address2], 100))
          add_pair(post, :BillingCity, truncate(billing_address[:city], 40))
          add_pair(post, :BillingState, truncate(billing_address[:state], 2)) if usa?(billing_address[:country])
          add_pair(post, :BillingCountry, truncate(billing_address[:country], 2))
          add_pair(post, :BillingPhone, sanitize_phone(billing_address[:phone]))
          add_pair(post, :BillingPostCode, truncate(billing_address[:zip], 10))
        end

        if shipping_address = options[:shipping_address] || billing_address
          first_name, last_name = split_names(shipping_address[:name])
          add_pair(post, :DeliverySurname, truncate(last_name, 20))
          add_pair(post, :DeliveryFirstnames, truncate(first_name, 20))
          add_pair(post, :DeliveryAddress1, truncate(shipping_address[:address1], 100))
          add_pair(post, :DeliveryAddress2, truncate(shipping_address[:address2], 100))
          add_pair(post, :DeliveryCity, truncate(shipping_address[:city], 40))
          add_pair(post, :DeliveryState, truncate(shipping_address[:state], 2)) if usa?(shipping_address[:country])
          add_pair(post, :DeliveryCountry, truncate(shipping_address[:country], 2))
          add_pair(post, :DeliveryPhone, sanitize_phone(shipping_address[:phone]))
          add_pair(post, :DeliveryPostCode, truncate(shipping_address[:zip], 10))
        end
      end

      def add_invoice(post, options)
        add_pair(post, :VendorTxCode, sanitize_order_id(options[:order_id]), required: true)
        add_pair(post, :Description, truncate(options[:description] || options[:order_id], 100))
      end

      def add_payment_method(post, payment_method, options)
        if payment_method.is_a?(String)
          if past_purchase_reference?(payment_method)
            add_related_reference(post, payment_method)
          else
            add_token_details(post, payment_method, options)
          end
        else
          add_credit_card(post, payment_method)
        end
      end

      def add_credit_card(post, credit_card)
        add_pair(post, :CardHolder, truncate(credit_card.name, 50), required: true)
        add_pair(post, :CardNumber, credit_card.number, required: true)

        add_pair(post, :ExpiryDate, format_date(credit_card.month, credit_card.year), required: true)
        add_pair(post, :CardType, map_card_type(credit_card))

        add_pair(post, :CV2, credit_card.verification_value)
      end

      def add_token_details(post, token, options)
        add_token(post, token)
        add_pair(post, :StoreToken, options[:customer])
        add_pair(post, :CV2, options[:verification_value])
      end

      def add_token(post, token)
        add_pair(post, :Token, token)
      end

      def sanitize_order_id(order_id)
        cleansed = order_id.to_s.gsub(/[^-a-zA-Z0-9._]/, '')
        truncate(cleansed, 40)
      end

      def sanitize_phone(phone)
        return nil unless phone

        cleansed = phone.to_s.gsub(/[^0-9+]/, '')
        truncate(cleansed, 20)
      end

      def usa?(country)
        truncate(country, 2) == 'US'
      end

      def map_card_type(credit_card)
        raise ArgumentError, 'The credit card type must be provided' if card_brand(credit_card).blank?

        card_type = card_brand(credit_card).to_sym

        if card_type == :visa && credit_card.electron?
          CREDIT_CARDS[:electron]
        else
          CREDIT_CARDS[card_type]
        end
      end

      # MMYY format
      def format_date(month, year)
        return nil if year.blank? || month.blank?

        year  = sprintf('%.4i', year)
        month = sprintf('%.2i', month)

        "#{month}#{year[-2..-1]}"
      end

      def commit(action, parameters)
        response = parse(ssl_post(url_for(action), post_data(action, parameters)))

        Response.new(response['Status'] == APPROVED, message_from(response), response,
          test: test?,
          authorization: authorization_from(response, parameters, action),
          avs_result: {
            street_match: AVS_CODE[response['AddressResult']],
            postal_match: AVS_CODE[response['PostCodeResult']]
          },
          cvv_result: CVV_CODE[response['CV2Result']]
        )
      end

      def authorization_from(response, params, action)
        case action
        when :store
          response['Token']
        else
          [params[:VendorTxCode],
           response['VPSTxId'] || params[:VPSTxId],
           response['TxAuthNo'],
           response['SecurityKey'] || params[:SecurityKey],
           action].join(';')
        end
      end

      def abort_or_void_from(identification)
        original_transaction = identification.split(';').last
        original_transaction == 'authorization' ? :abort : :void
      end

      def url_for(action)
        simulate ? build_simulator_url(action) : build_url(action)
      end

      def build_url(action)
        endpoint =
          case action
          when :purchase, :authorization then 'vspdirect-register'
          when :store then 'directtoken'
          else TRANSACTIONS[action].downcase
          end
        "#{test? ? self.test_url : self.live_url}/#{endpoint}.vsp"
      end

      def build_simulator_url(action)
        endpoint = %i[purchase authorization].include?(action) ? 'VSPDirectGateway.asp' : "VSPServerGateway.asp?Service=Vendor#{TRANSACTIONS[action].capitalize}Tx"
        "#{self.simulator_url}/#{endpoint}"
      end

      def message_from(response)
        response['Status'] == APPROVED ? 'Success' : (response['StatusDetail'] || 'Unspecified error') # simonr 20080207 can't actually get non-nil blanks, so this is shorter
      end

      def post_data(action, parameters = {})
        parameters.update(
          Vendor: @options[:login],
          TxType: TRANSACTIONS[action],
          VPSProtocol: @options.fetch(:protocol_version, '3.00')
        )

        parameters.update(ReferrerID: application_id) if application_id && (application_id != Gateway.application_id)

        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end

      # SagePay returns data in the following format
      # Key1=value1
      # Key2=value2
      def parse(body)
        result = {}
        body.to_s.each_line do |pair|
          result[$1] = $2 if pair.strip =~ /\A([^=]+)=(.+)\Z/im
        end
        result
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end

      def past_purchase_reference?(payment_method)
        return false unless payment_method.is_a?(String)

        payment_method.split(';').last == 'purchase'
      end
    end
  end
end
