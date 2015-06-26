module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MercuryEncryptedGateway < Gateway
      self.test_url = 'https://w1.mercurycert.net/PaymentsAPI/'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.example.net/'
      self.display_name = 'Mercury Gateway E2E'

      STANDARD_ERROR_CODE_MAPPING = {
        '100204' => STANDARD_ERROR_CODE[:invalid_number],
        '100205' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '000000' => STANDARD_ERROR_CODE[:card_declined]
      }
      SUCCESS_CODES = [ 'Approved', 'Success' ]

      def initialize(options={})
        requires!(options, :some_credential, :another_credential)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)

        add_payment(post, payment)


        commit('/Credit/Sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
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
        transcript
      end

      private

      def add_invoice(post, money, options)
        post['InvoiceNo'] = options[:invoice_no]
        post['RefNo'] = (options[:ref_no] || options[:invoice_no])
        post['OperatorID'] = options[:merchant] if options[:merchant]
        post['Memo'] = options[:description] if options[:description]
        post['Purchase'] = amount(money)
        #post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        post['EncryptedBlock'] = payment.split("|")[3]
        post['EncryptedKey'] = payment.split("|")[9]
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        parameters["RefNo"]           = "1"
        parameters["Memo"]            = "MPS Example JSON v1.0"
        parameters["Purchase"]        = "1.00"
        parameters["Frequency"]       = "OneTime"
        parameters["EncryptedFormat"] = "MagneSafe"
        parameters["AccountSource"]   = "Swiped"
        parameters["RecordNo"]        = "RecordNumberRequested"

        response = ssl_post(url + action, parameters.to_param, headers)
        response = CGI.parse(response || "")

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers
        headers = {
          "Authorization" => "Basic " + Base64.encode64("019588466313922"+":"+ "xyz").strip
        }
      end

      def success_from(response)
        response["CmdStatus"].present? && SUCCESS_CODES.include?(response["CmdStatus"].first)
      end

      def message_from(response)
        response[:text_response]
      end

      def authorization_from(response)
        response["RecordNo"].first
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response["DSIXReturnCode"]]
        end
      end
    end
  end
end
