module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AxcessmsGateway < Gateway
      include Empty

      self.test_url = 'https://eu-test.oppwa.com/'
      self.live_url = 'https://eu-prod.oppwa.com/'

      self.supported_countries = %w(AD AT BE BG BR CA CH CY CZ DE DK EE ES FI FO FR GB
                                    GI GR HR HU IE IL IM IS IT LI LT LU LV MC MT MX NL
                                    NO PL PT RO RU SE SI SK TR US VA)

      self.supported_cardtypes = %i[visa master american_express discover jcb maestro]

      self.homepage_url = 'http://www.axcessms.com/'
      self.display_name = 'Axcess MS'
      self.money_format = :dollars
      self.default_currency = 'GBP'

      API_VERSION = 'v1'
      PAYMENT_CODE_PREAUTHORIZATION = 'PA'
      PAYMENT_CODE_DEBIT = 'DB'
      PAYMENT_CODE_CAPTURE = 'CP'
      PAYMENT_CODE_REVERSAL = 'RV'
      PAYMENT_CODE_REFUND = 'RF'
      PAYMENT_CODE_REBILL = 'RB'

      SUCCESS_CODES = %w[000.000.100 000.000.100 000.100.110]
      SOFT_DECLINE_CODES = %w{
        800.100.201 800.100.203 800.100.204 100.150.204 000.100.204
        000.100.205 800.100.205 000.100.221 000.100.223 000.100.225
        000.100.226 300.100.100
      }.freeze

      def initialize(options = {})
        requires!(options, :token, :entityId)
        super
        @response_http_code = nil
      end

      def authorize(money, payment_method, options = {})
        post = {}
        add_card_details(post, payment_method, options)
        add_three_d_secure_data(post, money, options) if options[:three_d_secure_data].present?
        add_request_details(post, PAYMENT_CODE_PREAUTHORIZATION, money, options)
        commit(post)
      end

      def purchase(money, payment_method, options = {})
        post = {}
        add_three_d_secure_data(post, money, options) if options[:three_d_secure_data].present?
        add_card_details(post, payment_method, options)
        add_request_details(post, PAYMENT_CODE_DEBIT, money, options)
        commit(post)
      end

      def rebill(money, transaction_id, options = {})
        post = {}
        add_request_details(post, PAYMENT_CODE_REBILL, money, options)
        commit(post, transaction_id)
      end

      def capture(money, transaction_id, options = {})
        post = {}
        add_request_details(post, PAYMENT_CODE_CAPTURE, money, options)
        commit(post, transaction_id)
      end

      def refund(money, transaction_id, options = {})
        post = {}
        add_request_details(post, PAYMENT_CODE_REFUND, money, options)
        commit(post, transaction_id)
      end

      def void(money, transaction_id, options = {})
        post = {}
        add_request_details(post, PAYMENT_CODE_REVERSAL, money, options)
        commit(post, transaction_id)
      end

      def confirm(transaction_id)
        post = {}
        commit(post, transaction_id, 'confirm')
      end

      private

      def add_card_details(post, payment_method, options)
        post["customer.email"] = options[:email]
        post["customer.ip"] = options[:ip]
        post["card.number"] = payment_method.number
        post["card.holder"] = payment_method.name
        post["card.expiryMonth"] = format(payment_method.month, :two_digits)
        post["card.expiryYear"] = format(payment_method.year, :four_digits)
        post["card.cvv"] = payment_method.verification_value unless empty?(payment_method.verification_value)
        post["shopperResultUrl"] = options[:redirect_links][:success_url]
        if options[:billing_address].present?
          post["billing.street1"] = options[:billing_address][:address1]
          post["billing.street2"] = options[:billing_address][:address2]
          post["billing.city"] = options[:billing_address][:city]
          post["billing.postcode"] = options[:billing_address][:zip]
          post["billing.state"] = options[:billing_address][:state]
          post["billing.country"] = options[:billing_address][:country]
          post['customer.phone'] = options[:billing_address][:phone]
        end
        if options[:shipping_address].present?
          post["shipping.street1"] = options[:shipping_address][:address1]
          post["shipping.street2"] = options[:shipping_address][:address2]
          post["shipping.city"] = options[:shipping_address][:city]
          post["shipping.postcode"] = options[:shipping_address][:zip]
          post["shipping.state"] = options[:shipping_address][:state]
          post["shipping.country"] = options[:shipping_address][:country]
          post['customer.phone'] = options[:shipping_address][:phone]
        end
        post["customer.browser.userAgent"] = options[:browser_details][:identity]
      end

      def add_request_details(post, payment_code, money, options)
        post["amount"] = money
        post["currency"] = options[:currency]
        post["paymentType"] = payment_code
      end

      def add_three_d_secure_data(post, money, options)
        post["threeDSecure.challengeIndicator"]= options[:three_d_secure_data][:challengeIndicator]
        post["threeDSecure.exemptionFlag"]= options[:three_d_secure_data][:exemptionFlag]
        post["threeDSecure.verificationId"]= options[:three_d_secure_data][:verificationId]
        post["threeDSecure.eci"]= options[:three_d_secure_data][:eci]
        post["threeDSecure.xid"]= options[:three_d_secure_data][:xid]
      end

      def commit(params, transaction_id = "", action=nil)
        params = params.merge("entityId" => @options[:entityId])
        path = generate_path(action, transaction_id)
        uri = URI(path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(uri.path)
        req['Authorization'] = 'Bearer ' + @options[:token]
        req.set_form_data(params)
        res = http.request(req)
        response_data = JSON.parse(res.body)
        succeeded = success_from(response_data)
        Response.new(
          succeeded,
          message_from(succeeded, response_data),
          response_data,
          authorization: authorization_from(response_data, params["paymentType"]),
          test: test?,
          response_http_code: @response_http_code,
          request_endpoint: path,
          request_method: :post,
          request_body: params
        )
      end

      def url
        test? ? test_url : live_url
      end

      def generate_path(action, transaction_id)
        base_path = "#{url}#{API_VERSION}/"
        path_suffix = action == 'confirm' ? 'threeDSecure' : 'payments'
        path = "#{base_path}#{path_suffix}"
        path << "/#{transaction_id}" if transaction_id.present?
        path
      end

      def authorization_from(response, payment_type)
        authorization = response["id"].present? ? response["id"] : "Failed"
        [authorization, payment_type].join('#')
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response.dig('result', 'description') == 'transaction pending' ? '3DS_REQUIRED' : response.dig('result', 'description')
        end
      end

      def success_from(response)
        code = response.dig('result', 'code')
        SUCCESS_CODES.include?(code)
      end


      def response_type(code)
        if code == SUCCESS_CODE
          0
        elsif SOFT_DECLINE_CODES.include?(code)
          1
        else
          2
        end
      end

      def handle_response(response)
        @response_http_code = response.code.to_i
        case @response_http_code
        when 200...300
          response.body
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
