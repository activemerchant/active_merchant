module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MercuryEncryptedGateway < Gateway
      self.test_url = 'https://w1.mercurycert.net/PaymentsAPI'
      self.live_url = 'https://w1.mercurypay.com/PaymentsAPI'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://mercurypay.com/'
      self.display_name = 'Mercury Gateway E2E'

      STANDARD_ERROR_CODE_MAPPING = {
        '100204' => STANDARD_ERROR_CODE[:invalid_number],
        '100205' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '000000' => STANDARD_ERROR_CODE[:card_declined]
      }
      SUCCESS_CODES = [ 'Approved', 'Success' ]

      def initialize(options={})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        if payment.is_a?(Hash) || (payment.is_a?(String) && payment.include?('|'))
          add_payment(post, payment)
          commit('/Credit/Sale', post)
        else
          post["RecordNo"] = payment
          commit('/Credit/SaleByRecordNo', post)
        end
      end

      def authorize(money, swiper_output, options={})
        requires!(options, :invoice_no)
        post = {}
        add_invoice(post, money, options)
        add_payment(post, swiper_output)

        post["Authorize"] ||= post["Purchase"]

        commit('/Credit/PreAuth', post)
      end

      def capture(money, authorization, options={})
        requires!(options, :invoice_no, :auth_code, :acq_ref_data)
        post = {}
        add_invoice(post, money, options)

        post["RecordNo"] = authorization
        post["AuthCode"] = options[:auth_code]
        post["AcqRefData"] = options[:acq_ref_data]
        
        commit('/Credit/PreAuthCaptureByRecordNo', post)
      end

      def refund(money, authorization, options={})
        requires!(options, :invoice_no)
        post = {}
        add_invoice(post, money, options)

        post["RecordNo"] = authorization
        
        commit('/Credit/ReturnByRecordNo', post)
      end

      def void(authorization, options={})
        requires!(options, :invoice_no, :auth_code, :purchase)
        post = {}
        add_invoice(post, nil, options)
        
        post["RecordNo"] = authorization
        post["AuthCode"] = options[:auth_code]

        commit('/Credit/VoidSaleByRecordNo', post)
      end

      def supports_scrubbing?
        false
      end

      private

      def add_invoice(post, money, options)
        money = options[:purchase] if money.nil?
        post['InvoiceNo'] = options[:invoice_no]
        post['RefNo'] = (options[:ref_no] || options[:invoice_no])
        post['OperatorID'] = options[:merchant] if options[:merchant]
        post['Memo'] = options[:description] if options[:description]
        post['Purchase'] = amount(money) if money
        post['Authorize'] = amount(options[:authorized]) if options[:authorized]
        post['Gratuity'] = amount(options[:tip]) if options[:tip]
        post['LaneID'] = options[:lane_id] if options[:lane_id]
      end

      def add_payment(post, payment)
        post["EncryptedFormat"] = "MagneSafe"
        if payment.is_a?(Hash)
          post['EncryptedBlock'] = payment[:encrypted_block]
          post['EncryptedKey'] = payment[:encrypted_key]
        else
          post['EncryptedBlock'] = payment.split("|")[3]
          post['EncryptedKey'] = payment.split("|")[9]
        end
      end

      def add_common_params post
        post["Memo"] ||= "via ActiveMerchant"
        post["Frequency"] ||= "OneTime"
        post["AccountSource"] ||= "Swiped"
        post["RecordNo"] ||= "RecordNumberRequested"
      end

      def parse response
        CGI.parse(response).inject({}){|h,(k, v)| h[k] = v.first; h }
      end

      def commit(action, post)
        add_common_params(post)
        url = (test? ? test_url : live_url)

        response = parse(ssl_post(url + action, post.to_param, headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
          )
      rescue ActiveMerchant::ResponseError => e
        # treat auth failures as an error response
        if 401 == e.response.code.to_i && "Not Authorized" == e.response.message
          Response.new(
            false,
            e.message,
            {},
            { test: test? }
            )
        else
          raise
        end
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.encode64(@options[:login] +":"+ @options[:password]).strip
        }
      end

      def success_from(response)
        response["CmdStatus"].present? && SUCCESS_CODES.include?(response["CmdStatus"])
      end

      def message_from(response)
        response["TextResponse"]
      end

      def authorization_from(response)
        response["RecordNo"]
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response["DSIXReturnCode"]]
        end
      end
    end
  end
end
