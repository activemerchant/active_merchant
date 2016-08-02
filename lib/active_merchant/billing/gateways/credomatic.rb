require 'time'
require 'digest/md5'
require 'uri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CredomaticGateway < Gateway
      # No Test URL
      self.test_url = 'https://paycom.credomatic.com/PayComBackEndWeb/common/requestPaycomService.go'
      self.live_url = 'https://paycom.credomatic.com/PayComBackEndWeb/common/requestPaycomService.go'

      self.supported_countries = ['NI']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      self.homepage_url = 'https://www.credomatic.com'
      self.display_name = 'Credomatic'

      # @TODO
      STANDARD_ERROR_CODE_MAPPING = {
        '200' => STANDARD_ERROR_CODE[:card_declined],
        '300' => STANDARD_ERROR_CODE[:processing_error],
        '303' => STANDARD_ERROR_CODE[:processing_error],
        '305' => STANDARD_ERROR_CODE[:invalid_number],
      }

      def initialize(options={})
        requires!(options, :username, :key, :key_id)
        super
      end

      # @TODO: Check if it is posible
      def purchase(money, payment, options={})
        requires!(options, :order_id)
        post = {}
        add_invoice(post, money, options)
        add_invoice_data(post, options)
        add_payment(post, payment)
        add_hash_and_time(post, options)
        add_additional_options(post, options)
        commit('sale', post)
      end

      def authorize(money, payment, options={})
        requires!(options, :order_id)
        post = {}
        add_invoice(post, money, options)
        add_invoice_data(post, options)
        add_payment(post, payment)
        add_hash_and_time(post, options)
        add_additional_options(post, options)
        commit('auth', post)
      end

      # @TODO: Check if it is posible
      def capture(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        add_reference(post, authorization)
        commit('capture', post)
      end

      # @TODO: Check if it is posible
      def refund(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        add_reference(post, authorization)
        commit('refund', post)
      end

      # @TODO: Check if it is posible
      def void(authorization, options={})
        post = {}
        add_invoice(post, money, options)
        add_reference(post, authorization)
        commit('void', post)
      end

      # @TODO: Check if it is posible
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
          .gsub(%r((&?username=)\w*(&?)), '\1[FILTERED]\2')
          .gsub(%r((&?hash=)\w*(&?)), '\1[FILTERED]\2')
          .gsub(%r((&?ccnumber=)\w*(&?)), '\1[FILTERED]\2')
          .gsub(%r((&?ccexp=)\w*(&?)), '\1[FILTERED]\2')
          .gsub(%r((&?cvv=)\w*(&?)), '\1[FILTERED]\2')
          .gsub(%r((&?key_id=)\w*(&?)), '\1[FILTERED]\2')
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_invoice_data(post, options)
        post[:orderid] = options[:order_id]
      end

      def add_payment(post, payment)
        post[:ccnumber] = payment.number
        post[:ccexp] = format(payment.month, :two_digits) + format(payment.year, :two_digits)
        post[:cvv] = payment.verification_value        
      end

      def add_hash_and_time(post, options)
        time = Time.now.to_i.to_s
        # md5 (orderid|amount|time|key)
        hash = Digest::MD5.hexdigest("#{post[:orderid]}|#{post[:amount]}|#{time}|#{@options[:key]}")
        post[:hash] = hash
        post[:time] = time
      end

      def add_additional_options(post, options)
        other_options = [:avs, :zip, :processor_id]
        other_options.each do |op|
          post[op] = options[op] if options.has_key?(op)
        end
      end

      def parse(body)
        clean_array_query = URI.decode_www_form(URI.parse(body).query)
        hashed_response = Hash[clean_array_query].symbolize_keys
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,          
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response[:cvvresponse]),
          cvv_result: CVVResult.new(response[:cvvresponse]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response[:response] == "1"
      end

      def message_from(response)
        response[:responsetext]
      end

      # authcode|transactionid|purshamount
      def authorization_from(response)
        [
          response[:authcode],
          response[:transactionid],
          response[:purshamount]
        ].join("|")
      end

      def split_authorization(authorization)
        transactionid, authcode, time, purshamount = authorization.split("|")
        [transactionid, authcode, time, purshamount]
      end

      def add_reference(post, authorization)
        transactionid, authcode, time, purshamount = split_authorization
        post[:transactionid] = transactionid
        post[:authcode] = authcode
        post[:time] = time
        post[:purshamount] = purshamount
      end

      def post_data(action, parameters = {})
        post = {}
        post[:type] = action
        post[:username] = @options[:username]
        post[:key_id] = @options[:key_id]
        post[:redirect] = 'http://localhost'
        a = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      # Rewrite default activemerchant handle_response
      # because Credomatic return the data on a location redirect
      def handle_response(response)
        case response.code.to_i
        when 200...300
          response.body
        when 302
          response.fetch('location')
        else
          raise ResponseError.new(response)
        end
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response[:response_code]]
        end
      end
    end
  end
end
