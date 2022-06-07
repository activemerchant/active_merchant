module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MokaGateway < Gateway
      self.test_url = 'https://service.refmoka.com'
      self.live_url = 'https://service.moka.com'

      self.supported_countries = %w[GB TR US]
      self.default_currency = 'TRY'
      self.money_format = :dollars
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'http://developer.moka.com/'
      self.display_name = 'Moka'

      ERROR_CODE_MAPPING = {
        '000' =>	'General error',
        '001' =>	'3D Not authenticated',
        '002' =>	'Limit is insufficient',
        '003' =>	'Credit card number format is wrong',
        '004' =>	'General decline',
        '005' =>	'This process is invalid for the card owner',
        '006' =>	'Expiration date is wrong',
        '007' =>	'Invalid transaction',
        '008' =>	'Connection with the bank not established',
        '009' =>	'Undefined error code',
        '010' =>	'Bank SSL error',
        '011' =>	'Call the bank for the manual authentication',
        '012' =>	'Card info is wrong - Kart Number or CVV2',
        '013' =>	'3D secure is not supported other than Visa MC cards',
        '014' =>	'Invalid account number',
        '015' =>	'CVV is wrong',
        '016' =>	'Authentication process is not present',
        '017' =>	'System error',
        '018' =>	'Stolen card',
        '019' =>	'Lost card',
        '020' =>	'Card with limited properties',
        '021' =>	'Timeout',
        '022' =>	'Invalid merchant',
        '023' =>	'False authentication',
        '024' =>	'3D authorization is successful but the process cannot be completed',
        '025' =>	'3D authorization failure',
        '026' =>	'Either the issuer bank or the card is not enrolled to the 3D process',
        '027' =>	'The bank did not allow the process',
        '028' =>	'Fraud suspect',
        '029' =>	'The card is closed to the e-commerce operations'
      }

      def initialize(options = {})
        requires!(options, :dealer_code, :username, :password)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        post[:PaymentDealerRequest] = {}
        options[:pre_auth] = 0
        add_auth_purchase(post, money, payment, options)
        add_3ds_data(post, options) if options[:execute_threed]

        action = options[:execute_threed] ? 'three_ds_purchase' : 'purchase'
        commit(action, post)
      end

      def authorize(money, payment, options = {})
        post = {}
        post[:PaymentDealerRequest] = {}
        options[:pre_auth] = 1
        add_auth_purchase(post, money, payment, options)
        add_3ds_data(post, options) if options[:execute_threed]

        action = options[:execute_threed] ? 'three_ds_authorize' : 'authorize'
        commit(action, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post[:PaymentDealerRequest] = {}
        add_payment_dealer_authentication(post)
        add_transaction_reference(post, authorization)
        add_invoice(post, money, options)

        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:PaymentDealerRequest] = {}
        add_payment_dealer_authentication(post)
        add_transaction_reference(post, authorization)
        add_void_refund_reason(post)
        add_amount(post, money)

        commit('refund', post)
      end

      def void(authorization, options = {})
        post = {}
        post[:PaymentDealerRequest] = {}
        add_payment_dealer_authentication(post)
        add_transaction_reference(post, authorization)
        add_void_refund_reason(post)

        commit('void', post)
      end

      def verify(credit_card, options = {})
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
          gsub(%r(("CardNumber\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("CvcNumber\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("DealerCode\\?":\\?"?)[^"?]*)i, '\1[FILTERED]').
          gsub(%r(("Username\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("Password\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("CheckKey\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def add_auth_purchase(post, money, payment, options)
        add_payment_dealer_authentication(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_additional_auth_purchase_data(post, options)
        add_additional_transaction_data(post, options)
        add_buyer_information(post, payment, options)
        add_basket_product(post, options[:basket_product]) if options[:basket_product]
      end

      def add_3ds_data(post, options)
        post[:PaymentDealerRequest][:ReturnHash] = 1
        post[:PaymentDealerRequest][:RedirectUrl] = options[:redirect_url] || ''
        post[:PaymentDealerRequest][:RedirectType] = options[:redirect_type] || 0
      end

      def add_payment_dealer_authentication(post)
        post[:PaymentDealerAuthentication] = {
          DealerCode: @options[:dealer_code],
          Username: @options[:username],
          Password: @options[:password],
          CheckKey: check_key
        }
      end

      def check_key
        str = "#{@options[:dealer_code]}MK#{@options[:username]}PD#{@options[:password]}"
        Digest::SHA256.hexdigest(str)
      end

      def add_invoice(post, money, options)
        post[:PaymentDealerRequest][:Amount] = amount(money) || 0
        post[:PaymentDealerRequest][:Currency] = options[:currency] || 'TL'
      end

      def add_payment(post, card)
        post[:PaymentDealerRequest][:CardHolderFullName] = card.name
        post[:PaymentDealerRequest][:CardNumber] = card.number
        post[:PaymentDealerRequest][:ExpMonth] = card.month.to_s.rjust(2, '0')
        post[:PaymentDealerRequest][:ExpYear] = card.year
        post[:PaymentDealerRequest][:CvcNumber] = card.verification_value || ''
      end

      def add_amount(post, money)
        post[:PaymentDealerRequest][:Amount] = amount(money) || 0
      end

      def add_additional_auth_purchase_data(post, options)
        post[:PaymentDealerRequest][:IsPreAuth] = options[:pre_auth]
        post[:PaymentDealerRequest][:Description] = options[:description] if options[:description]
        post[:PaymentDealerRequest][:InstallmentNumber] = options[:installment_number].to_i if options[:installment_number]
        post[:SubMerchantName] = options[:sub_merchant_name] if options[:sub_merchant_name]
        post[:IsPoolPayment] = options[:is_pool_payment] || 0
      end

      def add_buyer_information(post, card, options)
        obj = {}

        obj[:BuyerFullName] = card.name || ''
        obj[:BuyerEmail] = options[:email] if options[:email]
        obj[:BuyerAddress] = options[:billing_address][:address1] if options[:billing_address]
        obj[:BuyerGsmNumber] = options[:billing_address][:phone] if options[:billing_address]

        post[:PaymentDealerRequest][:BuyerInformation] = obj
      end

      def add_basket_product(post, basket_options)
        basket = []

        basket_options.each do |product|
          obj = {}
          obj[:ProductId] = product[:product_id] if product[:product_id]
          obj[:ProductCode] = product[:product_code] if product[:product_code]
          obj[:UnitPrice] = amount(product[:unit_price]) if product[:unit_price]
          obj[:Quantity] = product[:quantity] if product[:quantity]
          basket << obj
        end

        post[:PaymentDealerRequest][:BasketProduct] = basket
      end

      def add_additional_transaction_data(post, options)
        post[:PaymentDealerRequest][:ClientIP] = options[:ip] if options[:ip]
        post[:PaymentDealerRequest][:OtherTrxCode] = options[:order_id] if options[:order_id]
      end

      def add_transaction_reference(post, authorization)
        post[:PaymentDealerRequest][:VirtualPosOrderId] = authorization
      end

      def add_void_refund_reason(post)
        post[:PaymentDealerRequest][:VoidRefundReason] = 2
      end

      def commit(action, parameters)
        response = parse(ssl_post(url(action), post_data(parameters), request_headers))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def url(action)
        host = (test? ? test_url : live_url)
        endpoint = endpoint(action)

        "#{host}/PaymentDealer/#{endpoint}"
      end

      def endpoint(action)
        case action
        when 'three_ds_authorize', 'three_ds_purchase'
          'DoDirectPaymentThreeD'
        when 'purchase', 'authorize'
          'DoDirectPayment'
        when 'capture'
          'DoCapture'
        when 'void'
          'DoVoid'
        when 'refund'
          'DoCreateRefundRequest'
        end
      end

      def request_headers
        { 'Content-Type' => 'application/json' }
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        return response.dig('Data', 'IsSuccessful') if response.dig('Data', 'IsSuccessful').to_s.present?

        response['ResultCode']&.casecmp('success') == 0
      end

      def message_from(response)
        response.dig('Data', 'ResultMessage').presence || response['ResultCode']
      end

      def authorization_from(response)
        response.dig('Data', 'VirtualPosOrderId')
      end

      def error_code_from(response)
        codes = [response['ResultCode'], response.dig('Data', 'ResultCode')].flatten
        codes.reject! { |code| code.blank? || code.casecmp('success').zero? }
        codes.map { |code| ERROR_CODE_MAPPING[code] || code }.join(', ')
      end
    end
  end
end
