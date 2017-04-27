module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      self.display_name = "GlobalCollect"
      self.homepage_url = "http://www.globalcollect.com/"

      self.test_url = "https://api-sandbox.globalcollect.com/"
      self.live_url = "https://api.globalcollect.com/"

      self.supported_countries = %w(AD AE AT AU BD BE BG BN CA CH CY CZ DE DK
      EE EG ES FI FR GB GI GR HK HU ID IE IL IM IN IS IT JO KW LB LI LK LT LU
      LV MC MT MU MV MX MY NL NO NZ OM PH PL PT QA RO SA SE SG SI SK SM TR TT
      UM US VA VN ZA)
      self.default_currency = "USD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      def initialize(options={})
        requires!(options, :merchant_id, :api_key_id, :secret_api_key)
        super
      end

      def purchase(money, payment, options={})
        MultiResponse.run do |r|
          r.process { authorize(money, payment, options) }
          r.process { capture(money, r.authorization, options) } unless capture_requested?(r)
        end
      end

      def authorize(money, payment, options={})
        post = nestable_hash
        add_order(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options, payment)
        add_address(post, payment, options)

        commit(:authorize, post)
      end

      def capture(money, authorization, options={})
        post = nestable_hash
        add_order(post, money, options)
        add_customer_data(post, options)
        commit(:capture, post, authorization)
      end

      def refund(money, authorization, options={})
        post = nestable_hash
        add_amount(post, money, options)
        add_refund_customer_data(post, options)
        commit(:refund, post, authorization)
      end

      def void(authorization, options={})
        post = nestable_hash
        commit(:void, post, authorization)
      end

      def verify(payment, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, payment, options) }
          r.process { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: )[^\\]*)i, '\1[FILTERED]').
          gsub(%r(("cardNumber\\":\\")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\":\\")\d+), '\1[FILTERED]')
      end

      private

      BRAND_MAP = {
        "visa" => "1",
        "american_express" => "2",
        "master" => "3",
        "discover" => "128",
        "jcb" => "125",
        "diners_club" => "132"
      }

      def add_order(post, money, options)
        post["order"]["amountOfMoney"] = {
          "amount" => amount(money),
          "currencyCode" => options[:currency] || currency(money)
        }
        post["order"]["references"] = {
          "merchantReference" => options[:order_id],
          "descriptor" => options[:description] # Max 256 chars
        }
        post["order"]["references"]["invoiceData"] = {
          "invoiceNumber" => options[:invoice]
        }
      end

      def add_amount(post, money, options={})
        post["amountOfMoney"] = {
          "amount" => amount(money),
          "currencyCode" => options[:currency] || currency(money)
        }
      end

      def add_payment(post, payment)
        year  = format(payment.year, :two_digits)
        month = format(payment.month, :two_digits)
        expirydate =   "#{month}#{year}"

        post["cardPaymentMethodSpecificInput"] = {
            "paymentProductId" => BRAND_MAP[payment.brand],
            "skipAuthentication" => "true", # refers to 3DSecure
            "skipFraudService" => "true"
        }
        post["cardPaymentMethodSpecificInput"]["card"] = {
            "cvv" => payment.verification_value,
            "cardNumber" => payment.number,
            "expiryDate" => expirydate,
            "cardholderName" => payment.name
        }
      end

      def add_customer_data(post, options, payment = nil)
        post["order"]["customer"] = {
          "merchantCustomerId" => options[:customer]
        }
        if payment
          post["order"]["customer"]["personalInformation"] = {
            "name" => {
              "firstName" => payment.first_name[0..14],
              "surname" => payment.last_name[0..69]
            }
          }
        end
        post["order"]["companyInformation"] = {
          "name" => options[:company]
        }
        post["order"]["contactDetails"] = {
          "emailAddress" => options[:email]
        }
        if address = options[:billing_address] || options[:address]
          post["order"]["contactDetails"] = {
            "phoneNumber" => address[:phone]
          }
        end
      end

      def add_refund_customer_data(post, options)
        if address = options[:billing_address] || options[:address]
          post["customer"]["address"] = {
            "countryCode" => address[:country]
          }
          post["customer"]["contactDetails"] = {
            "emailAddress" => options[:email],
            "phoneNumber" => address[:phone]
          }
        end
      end

      def add_address(post, creditcard, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address]
        if billing_address = options[:billing_address] || options[:address]
          post["order"]["customer"]["billingAddress"] = {
            "street" => billing_address[:address1],
            "additionalInfo" => billing_address[:address2],
            "zip" => billing_address[:zip],
            "city" => billing_address[:city],
            "state" => billing_address[:state],
            "countryCode" => billing_address[:country]
          }
        end
        if shipping_address
          post["order"]["customer"]["shippingAddress"] = {
            "street" => shipping_address[:address1],
            "additionalInfo" => shipping_address[:address2],
            "zip" => shipping_address[:zip],
            "city" => shipping_address[:city],
            "state" => shipping_address[:state],
            "countryCode" => shipping_address[:country]
          }
          post["order"]["customer"]["shippingAddress"]["name"] = {
            "firstName" => shipping_address[:firstname],
            "surname" => shipping_address[:lastname]
          }
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def url(action, authorization)
        (test? ? test_url : live_url) + uri(action, authorization)
      end

      def uri(action, authorization)
        uri = "/v1/#{@options[:merchant_id]}/"
        case action
        when :authorize
          uri + "payments"
        when :capture
          uri + "payments/#{authorization}/approve"
        when :refund
          uri + "payments/#{authorization}/refund"
        when :void
          uri + "payments/#{authorization}/cancel"
        end
      end

      def commit(action, post, authorization = nil)
        begin
          response = parse(ssl_post(url(action, authorization), post.to_json, headers(action, post, authorization)))
        rescue ResponseError => e
          if e.response.code.to_i >= 400
            response = parse(e.response.body)
          end
        end

        succeeded = success_from(response)
        Response.new(
        succeeded,
        message_from(succeeded, response),
        response,
        authorization: authorization_from(succeeded, response),
        error_code: error_code_from(succeeded, response),
        test: test?
        )

      end

      def headers(action, post, authorization = nil)
        {
          "Content-type"  => content_type,
          "Authorization" => auth_digest(action, post, authorization),
          "Date" => date
        }
      end

      def auth_digest(action, post, authorization = nil)
        data = <<-EOS
POST
#{content_type}
#{date}
#{uri(action, authorization)}
EOS
        digest = OpenSSL::Digest.new('sha256')
        key = @options[:secret_api_key]
        "GCS v1HMAC:#{@options[:api_key_id]}:#{Base64.strict_encode64(OpenSSL::HMAC.digest(digest, key, data))}"
      end

      def date
        @date ||= Time.now.strftime("%a, %d %b %Y %H:%M:%S %Z") # Must be same in digest and HTTP header
      end

      def content_type
        "application/json"
      end

      def success_from(response)
        !response["errorId"] && response["status"] != "REJECTED"
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          if errors = response["errors"]
            errors.first.try(:[], "message")
          elsif status = response["status"]
            "Status: " + status
          else
            "No message available"
          end
        end
      end

      def authorization_from(succeeded, response)
        if succeeded
          response["id"] || response["payment"]["id"] || response["paymentResult"]["payment"]["id"]
        else
          response["errorId"]
        end
      end

      def error_code_from(succeeded, response)
        unless succeeded
          if errors = response["errors"]
            errors.first.try(:[], "code")
          elsif status = response.try(:[], "statusOutput").try(:[], "statusCode")
            status.to_s
          else
            "No error code available"
          end
        end
      end

      def nestable_hash
        Hash.new {|h,k| h[k] = Hash.new(&h.default_proc) }
      end

      def capture_requested?(response)
        response.params.try(:[], "payment").try(:[], "status") == "CAPTURE_REQUESTED"
      end
    end
  end
end
