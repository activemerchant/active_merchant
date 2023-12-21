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

      def authorize(amount, payment_method, options = {})
        post = {}
        add_payment_method(post, payment_method, options)
        add_customer_details(post, options)
        add_three_d_secure_data(post, amount, options) if options[:three_d_secure_data].present?
        add_invoice_details(post, PAYMENT_CODE_PREAUTHORIZATION, amount, options)
        add_recurring_details(post, options)
        commit(:authorize, post)
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_payment_method(post, payment_method, options)
        add_customer_details(post, options)
        add_three_d_secure_data(post, amount, options) if options[:three_d_secure_data].present?
        add_invoice_details(post, PAYMENT_CODE_DEBIT, amount, options)
        add_recurring_details(post, options)
        commit(:purchase, post)
      end

      def registration_token_purchase(amount, payment_method, options)
        post = {}
        add_customer_details(post, options)
        add_invoice_details(post, PAYMENT_CODE_DEBIT, amount, options)
        add_repeated_recurring_details(post, options)
        commit(:registration_token_purchase, post, :post, payment_method)
      end

      def rebill(amount, authorization, options = {})
        post = {}
        add_invoice_details(post, PAYMENT_CODE_REBILL, amount, options)
        commit(:rebill, post, :post, authorization)
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_invoice_details(post, PAYMENT_CODE_CAPTURE, amount, options)
        commit(:capture, post, :post, authorization)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_invoice_details(post, PAYMENT_CODE_REFUND, amount, options)
        commit(:refund, post, :post, authorization)
      end

      def void(amount, authorization, options = {})
        post = {}
        add_invoice_details(post, PAYMENT_CODE_REVERSAL, amount, options)
        commit(:void, post, :post, authorization)
      end

      def confirm(authorization)
        post = {}
        commit(:confirm, post, :get, authorization)
      end

      private

      def add_payment_method(post, payment_method, options)
        post["createRegistration"] = true
        post["card.number"] = payment_method.number
        post["card.expiryMonth"] = format(payment_method.month, :two_digits)
        post["card.expiryYear"] = format(payment_method.year, :four_digits)
        post["card.cvv"] = payment_method.verification_value unless empty?(payment_method.verification_value)
        post["card.holder"] = options[:billing_address][:name] if options[:billing_address].present?
      end

      def add_customer_details(post, options)
        post["customer.email"] = options[:email]
        post["customer.ip"] = options[:ip]
        post["customer.browser.userAgent"] = options[:browser_details][:identity] if options[:browser_details].present?
        post["shopperResultUrl"] = options[:redirect_links][:success_url] if options[:redirect_links].present?

        if options[:billing_address].present?
          post["billing.street1"] = options[:billing_address][:address1]
          post["billing.street2"] = options[:billing_address][:address2]
          post["billing.city"] = options[:billing_address][:city]
          post["billing.postcode"] = options[:billing_address][:zip]
          post["billing.state"] = options[:billing_address][:state]
          post["billing.country"] = options[:billing_address][:country]
          post['customer.phone'] = options[:billing_address][:phone]
        end
      end

      def add_invoice_details(post, payment_code, amount, options)
        post["amount"] = amount
        post["currency"] = options[:currency]
        post["paymentType"] = payment_code
      end

      def add_three_d_secure_data(post, amount, options)
        post["threeDSecure.challengeIndicator"]= options[:three_d_secure_data][:challengeIndicator]
        post["threeDSecure.exemptionFlag"]= options[:three_d_secure_data][:exemptionFlag]
        post["threeDSecure.verificationId"]= options[:three_d_secure_data][:verificationId]
        post["threeDSecure.eci"]= options[:three_d_secure_data][:eci]
        post["threeDSecure.xid"]= options[:three_d_secure_data][:xid]
      end

      def add_recurring_details(post, options)
        post["standingInstruction.type"] = "RECURRING"
        post["standingInstruction.mode"] = "INITIAL"
        post["standingInstruction.source"] = "CIT"
      end

      def add_repeated_recurring_details(post, options)
        post["standingInstruction.type"] = "RECURRING"
        post["standingInstruction.mode"] = "REPEATED"
        post["standingInstruction.source"] = "MIT"
      end

      def commit(action, params, method = :post, authorization=nil)
        params = params.merge("entityId" => @options[:entityId])
        request_body = post_data(action, params)
        request_endpoint = url(action, authorization)
        raw_response =  if method == :post
                          ssl_post(request_endpoint, request_body, headers)
                        else
                          request_endpoint = request_endpoint + "?#{request_body}"
                          ssl_get(request_endpoint, headers)
                        end
        response = JSON.parse(raw_response)

        succeeded = success_from(response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response, params["paymentType"]),
          response_type: response_type(response.dig('result', 'code')),
          test: test?,
          response_http_code: @response_http_code,
          request_endpoint:,
          request_method: method,
          request_body: params
        )
      end

      def base_url
        test? ? test_url : live_url
      end

      def url(action, authorization)
        case action
        when :authorize, :purchase
          "#{base_url}#{API_VERSION}/payments"
        when :capture, :refund, :void, :rebill, :confirm
          "#{base_url}#{API_VERSION}/payments/#{split_authorization(authorization)}"
        when :registration_token_purchase
           "#{base_url}#{API_VERSION}/registrations/#{authorization}/payments"
        end
      end

      def headers
        headers = { 'Authorization' => 'Bearer ' + @options[:token] }
        headers
      end

      def post_data(action, params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def authorization_from(response, payment_type)
        authorization = response["id"].present? ? response["id"] : "Failed"
        [authorization, payment_type].join('#')
      end

      def split_authorization(authorization)
        transaction_id, = authorization.split('#')
        transaction_id
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
        if SUCCESS_CODES.include?(code)
          0
        elsif SOFT_DECLINE_CODES.include?(code)
          1
        else
          2
        end
      end

      def handle_response(response)
        @response_http_code = response.code.to_i
        response.body
      end
    end
  end
end
