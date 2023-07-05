require 'digest'
require 'jwe'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VposGateway < Gateway
      self.test_url = 'https://vpos.infonet.com.py:8888'
      self.live_url = 'https://vpos.infonet.com.py'

      self.supported_countries = ['PY']
      self.default_currency = 'PYG'
      self.supported_cardtypes = %i[visa master panal]

      self.homepage_url = 'https://comercios.bancard.com.py'
      self.display_name = 'vPOS'

      self.money_format = :dollars

      ENDPOINTS = {
        pci_encryption_key: '/vpos/api/0.3/application/encryption-key',
        pay_pci_buy_encrypted: '/vpos/api/0.3/pci/encrypted',
        pci_buy_rollback: '/vpos/api/0.3/pci_buy/rollback',
        refund: '/vpos/api/0.3/refunds'
      }

      def initialize(options = {})
        requires!(options, :private_key, :public_key)
        @private_key = options[:private_key]
        @public_key = options[:public_key]
        @encryption_key = OpenSSL::PKey::RSA.new(options[:encryption_key]) if options[:encryption_key]
        @shop_process_id = options[:shop_process_id] || SecureRandom.random_number(10**15)
        super
      end

      def purchase(money, payment, options = {})
        commerce = options[:commerce] || @options[:commerce]
        commerce_branch = options[:commerce_branch] || @options[:commerce_branch]
        shop_process_id = options[:shop_process_id] || @shop_process_id

        token = generate_token(shop_process_id, 'pay_pci', commerce, commerce_branch, amount(money), currency(money))

        post = {}
        post[:token] = token
        post[:commerce] = commerce.to_s
        post[:commerce_branch] = commerce_branch.to_s
        post[:shop_process_id] = shop_process_id
        post[:number_of_payments] = options[:number_of_payments] || 1
        post[:recursive] = options[:recursive] || false

        add_invoice(post, money, options)
        add_card_data(post, payment)
        add_customer_data(post, options)

        commit(:pay_pci_buy_encrypted, post)
      end

      def void(authorization, options = {})
        _, shop_process_id = authorization.to_s.split('#')
        token = generate_token(shop_process_id, 'rollback', '0.00')
        post = {
          token: token,
          shop_process_id: shop_process_id
        }
        commit(:pci_buy_rollback, post)
      end

      def credit(money, payment, options = {})
        # Not permitted for foreign cards.
        commerce = options[:commerce] || @options[:commerce]
        commerce_branch = options[:commerce_branch] || @options[:commerce_branch]

        token = generate_token(@shop_process_id, 'refund', commerce, commerce_branch, amount(money), currency(money))
        post = {}
        post[:token] = token
        post[:commerce] = commerce.to_i
        post[:commerce_branch] = commerce_branch.to_i
        post[:shop_process_id] = @shop_process_id
        add_invoice(post, money, options)
        add_card_data(post, payment)
        add_customer_data(post, options)
        post[:origin_shop_process_id] = options[:original_shop_process_id] if options[:original_shop_process_id]
        commit(:refund, post)
      end

      def refund(money, authorization, options = {})
        commerce = options[:commerce] || @options[:commerce]
        commerce_branch = options[:commerce_branch] || @options[:commerce_branch]
        shop_process_id = options[:shop_process_id] || @shop_process_id
        _, original_shop_process_id = authorization.to_s.split('#')

        token = generate_token(shop_process_id, 'refund', commerce, commerce_branch, amount(money), currency(money))
        post = {}
        post[:token] = token
        post[:commerce] = commerce.to_i
        post[:commerce_branch] = commerce_branch.to_i
        post[:shop_process_id] = shop_process_id
        add_invoice(post, money, options)
        add_customer_data(post, options)
        post[:origin_shop_process_id] = original_shop_process_id || options[:original_shop_process_id]
        commit(:refund, post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        clean_transcript = remove_invalid_utf_8_byte_sequences(transcript)
        clean_transcript.
          gsub(/(token\\":\\")[.\-\w]+/, '\1[FILTERED]').
          gsub(/(card_encrypted_data\\":\\")[.\-\w]+/, '\1[FILTERED]')
      end

      def remove_invalid_utf_8_byte_sequences(transcript)
        transcript.encode('UTF-8', 'binary', undef: :replace, replace: '')
      end

      # Required to encrypt PAN data.
      def one_time_public_key
        token = generate_token('get_encription_public_key', @public_key)
        response = commit(:pci_encryption_key, token: token)
        response.params['encryption_key']
      end

      private

      def generate_token(*elements)
        Digest::MD5.hexdigest(@private_key + elements.join)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = options[:currency] || currency(money)
      end

      def add_card_data(post, payment)
        card_number = payment.number
        cvv = payment.verification_value

        payload = { card_number: card_number, 'cvv': cvv }.to_json

        encryption_key = @encryption_key || OpenSSL::PKey::RSA.new(one_time_public_key)

        post[:card_encrypted_data] = JWE.encrypt(payload, encryption_key)
        post[:card_month_expiration] = format(payment.month, :two_digits)
        post[:card_year_expiration] = format(payment.year, :two_digits)
      end

      def add_customer_data(post, options)
        post[:additional_data] = options[:additional_data] || '' # must be passed even if empty
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = build_request_url(action)
        begin
          response = parse(ssl_post(url, post_data(parameters)))
        rescue ResponseError => response
          # Errors are returned with helpful data,
          # but get filtered out by `ssl_post` because of their HTTP status.
          response = parse(response.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: nil,
          cvv_result: nil,
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        if code = response.dig('confirmation', 'response_code')
          code == '00'
        else
          response['status'] == 'success'
        end
      end

      def message_from(response)
        %w(confirmation refund).each do |m|
          message =
            response.dig(m, 'extended_response_description') ||
            response.dig(m, 'response_description') ||
            response.dig(m, 'response_details')
          return message if message
        end
        [response.dig('messages', 0, 'key'), response.dig('messages', 0, 'dsc')].join(':')
      end

      def authorization_from(response)
        response_body = response.dig('confirmation') || response.dig('refund')
        return unless response_body

        authorization_number = response_body.dig('authorization_number') || response_body.dig('authorization_code')
        shop_process_id = response_body.dig('shop_process_id')

        "#{authorization_number}##{shop_process_id}"
      end

      def error_code_from(response)
        response.dig('confirmation', 'response_code') unless success_from(response)
      end

      def build_request_url(action)
        base_url = (test? ? test_url : live_url)
        base_url + ENDPOINTS[action]
      end

      def post_data(data)
        { public_key: @public_key,
          operation: data }.compact.to_json
      end
    end
  end
end
