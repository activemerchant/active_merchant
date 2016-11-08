require 'active_support/core_ext/string/filters'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AmazonPaymentsGateway < Gateway
      API_VERSION = '2013-01-01'

      self.test_url = 'https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01'
      self.live_url = 'https://mws.amazonservices.com/OffAmazonPayments/2013-01-01'

      self.supported_countries = ['US', 'JP', 'GB', 'DE', 'IN', 'FR', 'IT', 'ES']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]
      self.money_format = :cents

      self.homepage_url = 'https://payments.amazon.com/'
      self.display_name = 'Amazon Payments'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :merchant_id, :access_key, :secret_key)

        options[:region] ||= :us
        options[:currency] ||= self.default_currency
        options[:max_retries] ||= 0
        options[:retry_intervals] ||= [1, 2, 4, 8]

        super

        self.test_url = "https://#{endpoint_domain(options[:region])}/#{sandbox_str}/#{API_VERSION}"
        self.live_url = "https://#{endpoint_domain(options[:region])}/#{sandbox_str}/#{API_VERSION}"
      end

      def get_order_reference_details(order_reference_id, options={})
        post = {}
        add_order_reference_id(post, order_reference_id)
        add_address_consent_token(post, options[:address_consent_token])

        commit('GetOrderReferenceDetails', post)
      end

      def set_order_reference_details(order_reference_id, money, options={})
        post = {}
        add_order_reference_id(post, order_reference_id)
        add_order_reference_attributes(post, money, options)

        commit('SetOrderReferenceDetails', post)
      end

      def confirm_order_reference(order_reference_id)
        post = {}
        add_order_reference_id(post, order_reference_id)

        commit('ConfirmOrderReference', post)
      end

      def purchase(money, order_reference_id, options={})
        requires!(options, :authorization_reference_id, :capture_reference_id)

        MultiResponse.run do |r|
          r.process { authorize(money, order_reference_id, options) }
          r.process { capture(money, r.authorization, options) }
        end
      end

      def authorize(money, order_reference_id, options={})
        requires!(options, :authorization_reference_id)

        post = {}
        add_order_reference_id(post, order_reference_id)
        add_authorization_reference_id(post, options[:authorization_reference_id])
        add_authorization_amount(post, money)
        add_authorization_options(post, options)

        commit('Authorize', post)
      end

      def capture(money, authorization_id, options={})
        requires!(options, :capture_reference_id)

        post = {}
        add_authorization_id(post, authorization_id)
        add_capture_reference_id(post, options[:capture_reference_id])
        add_capture_amount(post, money)
        add_capture_options(post, options)

        commit('Capture', post)
      end

      def refund(money, capture_id, options={})
        requires!(options, :refund_reference_id)

        post = {}
        add_capture_id(post, capture_id)
        add_refund_reference_id(post, options[:refund_reference_id])
        add_refund_amount(post, money)
        add_refund_options(post, options)

        commit('Refund', post)
      end

      def close_authorization(authorization_id, options={})
        post = {}
        add_authorization_id(post, authorization_id)
        add_closure_reason(post, options[:closure_reason])

        commit('CloseAuthorization', post)
      end

      def close_order_reference(order_reference_id, options={})
        post = {}
        add_order_reference_id(post, order_reference_id)
        add_closure_reason(post, options[:closure_reason])

        commit('CloseOrderReference', post)
      end

      def cancel_order_reference(order_reference_id, options={})
        post = {}
        add_order_reference_id(post, order_reference_id)
        add_cancelation_reason(post, options[:cancelation_reason])

        commit('CancelOrderReference', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.gsub(%r((AWSAccessKeyId=)\w+), '\1[FILTERED]')
      end

      private

      def add_order_reference_id(post, order_reference_id)
        post['AmazonOrderReferenceId'] = order_reference_id
      end

      def add_address_consent_token(post, address_consent_token)
        post['AddressConsentToken'] = address_consent_token
      end

      def add_order_reference_attributes(post, money, options)
        post['OrderReferenceAttributes.OrderTotal.Amount'] = amount(money)
        post['OrderReferenceAttributes.OrderTotal.CurrencyCode'] = (@options[:currency] || currency(money))
        post['OrderReferenceAttributes.PlatformId'] = options[:platform_id]
        post['OrderReferenceAttributes.SellerNote'] = options[:seller_note]
        post['OrderReferenceAttributes.SellerOrderAttributes.SellerOrderId'] = options[:seller_order_id]
        post['OrderReferenceAttributes.SellerOrderAttributes.StoreName'] = options[:store_name]
      end

      def add_authorization_reference_id(post, authorization_reference_id)
        post['AuthorizationReferenceId'] = authorization_reference_id
      end

      def add_authorization_amount(post, money)
        post['AuthorizationAmount.Amount'] = amount(money)
        post['AuthorizationAmount.CurrencyCode'] = (@options[:currency] || currency(money))
      end

      def add_authorization_options(post, options)
        post['SellerAuthorizationNote'] = options[:seller_authorization_note]
        post['TransactionTimeout'] = options[:transaction_timeout]
        post['CaptureNow'] = options[:capture_now]
        post['SoftDescriptor'] = options[:soft_descriptor]
      end

      def add_authorization_id(post, authorization_id)
        post['AmazonAuthorizationId'] = authorization_id
      end

      def add_capture_reference_id(post, capture_reference_id)
        post['CaptureReferenceId'] = capture_reference_id
      end

      def add_capture_amount(post, money)
        post['CaptureAmount.Amount'] = amount(money)
        post['CaptureAmount.CurrencyCode'] = (@options[:currency] || currency(money))
      end

      def add_capture_options(post, options)
        post['SellerCaptureNote'] = options[:seller_capture_note]
        post['SoftDescriptor'] = options[:soft_descriptor]
      end

      def add_capture_id(post, capture_id)
        post['AmazonCaptureId'] = capture_id
      end

      def add_refund_reference_id(post, refund_reference_id)
        post['RefundReferenceId'] = refund_reference_id
      end

      def add_refund_amount(post, money)
        post['RefundAmount.Amount'] = amount(money)
        post['RefundAmount.CurrencyCode'] = (@options[:currency] || currency(money))
      end

      def add_refund_options(post, options)
        post['SellerRefundNote'] = options[:seller_refund_note]
        post['SoftDescriptor'] = options[:soft_descriptor]
      end

      def add_closure_reason(post, closure_reason)
        post['ClosureReason'] = closure_reason
      end

      def add_cancelation_reason(post, cancelation_reason)
        post['CancelationReason'] = cancelation_reason
      end

      def parse(body, action)
        results = {}
        return results unless body
        xml = Nokogiri::XML(body) do |config|
          config.options = Nokogiri::XML::ParseOptions::NOBLANKS
        end
        xml.remove_namespaces!
        nodes = xml.xpath("//#{action}Response | //ErrorResponse")
        nodes.each do |node|
          results[node.name] = parse_node(node, results[node.name])
        end
        results
      end

      def parse_node(node, results)
        return node.child.text if node.children.length == 1 && node.child.text?
        results = {}
        node.children.each do |child|
          results[child.name] = parse_node(child, results[child.name])
        end
        results
      end

      def commit(action, parameters)
        retries = 0
        begin
          response = parse(ssl_post(url, post_data(action, parameters)), action)
        rescue ResponseError => e
          # see: https://payments.amazon.com/developer/documentation/lpwa/201954950
          case e.response.code.to_i
          when 500, 502, 503, 504
            if retries < options[:max_retries]
              sleep options[:retry_intervals][retries]
              retries += 1
              retry
            end
          end
          response = parse(e.response.body, action)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        !response.empty? && !response['ErrorResponse']
      end

      def message_from(response)
        if response['ErrorResponse']
          response['ErrorResponse']['Error']['Message']
        else
          'Success'
        end
      end

      def authorization_from(response)
        if response['AuthorizeResponse']
          response['AuthorizeResponse']['AuthorizeResult']['AuthorizationDetails']['AmazonAuthorizationId']
        else
          nil
        end
      end

      def post_data(action, parameters = {})
        parameters.reject! { |k, v| v.nil? }
        hash = default_parameters.merge(parameters)
        hash['Action'] = action
        query_string = hash.sort.map { |k, v| "#{k}=#{ custom_escape(v) }" }.join("&")
        message = ["POST", "#{endpoint_domain(options[:region])}", "/#{sandbox_str}/#{API_VERSION}", query_string].join("\n")
        query_string += "&Signature=" + sign(message)
        query_string
      end

      def url
        test? ? self.test_url : self.live_url
      end

      def sandbox_str
        test? ? 'OffAmazonPayments_Sandbox' : 'OffAmazonPayments'
      end

      def default_parameters
        {
          'AWSAccessKeyId' => @options[:access_key],
          'SellerId' => @options[:merchant_id],
          'SignatureMethod' => 'HmacSHA256',
          'SignatureVersion' => '2',
          'Timestamp' => Time.now.utc.iso8601,
          'Version' => '2013-01-01'
        }
      end

      def sign(data)
        custom_escape(Base64.strict_encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, @options[:secret_key], data)))
      end

      def custom_escape(value)
        value.to_s.gsub(/([^\w.~-]+)/) do
          "%" + $1.unpack("H2" * $1.bytesize).join("%").upcase
        end
      end

      def error_code_from(response)
        return if success_from(response)
        return if response.empty?
        response['ErrorResponse']['Error']['Code']
      end

      def endpoint_domain(region)
        case region
        when :jp
          'mws.amazonservices.jp'
        when :uk
          'mws-eu.amazonservices.com'
        when :de
          'mws-eu.amazonservices.com'
        when :eu
          'mws-eu.amazonservices.com'
        when :us
          'mws.amazonservices.com'
        when :na
          'mws.amazonservices.com'
        else
          raise ArgumentError, "Unknown region code #{region}"
        end
      end
    end
  end
end
