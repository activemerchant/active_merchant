module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AxcessmsGateway < Gateway
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

      SUCCESS_CODE = '000.000.100'
      SOFT_DECLINE_CODES = [
        '800.100.201', '800.100.203', '800.100.204', '100.150.204', '000.100.204',
        '000.100.205', '800.100.205', '000.100.221', '000.100.223', '000.100.225',
        '000.100.226', '300.100.100'
      ]

      def initialize(options = {})
        requires!(options, :token)
        super
      end

      def authorize(money, credit_card, options = {})
        post = {}
        add_card_details(post, credit_card, options)
        add_request_details(post, PAYMENT_CODE_PREAUTHORIZATION, money, options)
        commit(post)
      end

      def purchase(money, credit_card, options = {})
        post = {}
        add_card_details(post, credit_card, options)
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

      private

      def add_card_details(post, credit_card, options)
        post["paymentBrand"] = options["paymentBrand"]
        post["card.number"] = credit_card["number"]
        post["card.holder"] = credit_card["holder"]
        post["card.expiryMonth"] = credit_card["expiryMonth"]
        post["card.expiryYear"] = credit_card["expiryYear"]
        post["card.cvv"] = credit_card["cvv"]
        if options["billing"].present?
          post["billing.street1"] = options["billing"]["street1"]
          post["billing.street2"] = options["billing"]["street2"]
          post["billing.city"] = options["billing"]["city"]
          post["billing.postcode"] = options["billing"]["postcode"]
          post["billing.state"] = options["billing"]["state"]
          post["billing.country"] = options["billing"]["country"]
        end
        if options["shipping"].present?
          post["shipping.street1"] = options["shipping"]["street1"]
          post["shipping.street2"] = options["shipping"]["street2"]
          post["shipping.city"] = options["shipping"]["city"]
          post["shipping.postcode"] = options["shipping"]["postcode"]
          post["shipping.state"] = options["shipping"]["state"]
          post["shipping.country"] = options["shipping"]["country"]
        end
        if options["customer"].present?
          post["customer.email"] = options["customer"]["email"]
          post["customer.mobile"] = options["customer"]["mobile"]
        end
      end

      def add_request_details(post, payment_code, money, options)
        post["entityId"] = options["entityId"]
        post["amount"] = money
        post["currency"] = options["currency"]
        post["paymentType"] = payment_code
      end

      def commit(params, transaction_id = "")
        path = "#{url}#{API_VERSION}/payments"
        path = "#{path}/#{transaction_id}" if transaction_id.present?
        uri = URI(path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(uri.path)
        req['Authorization'] = 'Bearer ' + @options[:token]
        req.set_form_data(params)
        res = http.request(req)
        response_data = JSON.parse(res.body)
        succeeded = success_from(res.message)
        Response.new(
          succeeded,
          message_from(succeeded, response_data),
          response_data,
          authorization: authorization_from(response_data, params["paymentType"]),
          test: test?,
          response_type: response_type(response.dig('result', 'code'))
        )
      end

      def url
        test? ? test_url : live_url
      end

      def authorization_from(response, payment_type)
        authorization = response["id"].present? ? response["id"] : "Failed"
        [authorization, payment_type].join('#')
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response["result"]["description"]
        end
      end

      def success_from(resonse_message)
        resonse_message == "OK"
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
    end
  end
end
