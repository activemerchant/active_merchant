require 'openssl'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ClearhausGateway < Gateway
      self.test_url = 'https://gateway.test.clearhaus.com'
      self.live_url = 'https://gateway.clearhaus.com'
      
      class_attribute :test_mpi_url, :live_mpi_url
      self.test_mpi_url = 'https://mpi.test.3dsecure.io'
      self.live_mpi_url = 'https://mpi.3dsecure.io'

      self.supported_countries = ['DK', 'NO', 'SE', 'FI', 'DE', 'CH', 'NL', 'AD', 'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'FO', 'GL', 'EE', 'FR', 'GR', 
                                  'HU', 'IS', 'IE', 'IT', 'LV', 'LI', 'LT', 'LU', 'MT', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'GB']

      self.default_currency    = 'EUR'
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://www.clearhaus.com'
      self.display_name = 'Clearhaus Gateway'
      self.money_format = :cents

      ACTION_CODE_MESSAGES = {
        20000 => 'Approved',
        40000 => 'General input error',
        40110 => 'Invalid card number',
        40120 => 'Invalid CSC',
        40130 => 'Invalid expire date',
        40135 => 'Card expired',
        40140 => 'Invalid currency',
        40200 => 'Clearhaus rule violation',
        40300 => '3-D Secure problem',
        40310 => '3-D Secure authentication failure',
        40400 => 'Backend problem',
        40410 => 'Declined by issuer or card scheme',
        40411 => 'Card restricted',
        40412 => 'Card lost or stolen',
        40413 => 'Insufficient funds',
        40414 => 'Suspected fraud',
        40415 => 'Amount limit exceeded',
        50000 => 'Clearhaus error'
      }

      # Create gateway
      #
      # options:
      #       :api_key - merchant's Clearhaus API Key
      #       :mpi_api_key - merchant's Clearhaus MPI (https://mpi.3dsecure.io) Key
      #       :signing_key - merchant's private key for optionally signing request
      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      # Make a purchase (authorize and capture)
      #
      # money          - The monetary amount of the transaction in cents.
      # payment        - The CreditCard or the Clearhaus card token.
      # options        - A standard ActiveMerchant options hash      
      def purchase(money, payment, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(money, payment, options) }
          r.process(:ignore_result) { capture(money, r.authorization, options) }
        end
      end

      # Authorize a transaction.
      #
      # money          - The monetary amount of the transaction in cents.
      # payment        - The CreditCard or the Clearhaus card token.
      # options        - A standard ActiveMerchant options hash  with optional pares    
      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        
        action = if payment.respond_to?(:number)
                   add_payment(post, payment)
                   "/authorizations"
                 else
                   "/cards/#{payment}/authorizations"
                 end

        add_recurrence_mode(post, options)
        add_3dsecure_data(post, options)

        commit(action, post)
      end

      # Capture a pre-authorized transaction.
      #
      # money          - The monetary amount of the transaction in cents.
      # authorization  - The Clearhaus authorization id string.
      # options        - A standard ActiveMerchant options hash
      def capture(money, authorization, options={})
        post = {}
        add_amount(post, money, options)

        commit("/authorizations/#{authorization}/captures", post)
      end

      # Refund a captured transaction (fully or partial).
      #
      # money          - The monetary amount of the transaction in cents.
      # authorization  - The Clearhaus authorization id string.
      # options        - A standard ActiveMerchant options hash
      def refund(money, authorization, options={})
        post = {}
        add_amount(post, money, options)

        commit("/authorizations/#{authorization}/refunds", post)
      end

      def void(authorization, options = {})
        commit("/authorizations/#{authorization}/voids", options)
      end

      def verify(credit_card, options={})
        MultiResponse.run() do |r|
          r.process { authorize(100, credit_card, options) }
          r.process { void(r.authorization, options) }
        end
      end

      # Tokenize credit card with Clearhaus.
      #
      # credit_card    - The CreditCard.
      # options        - A standard ActiveMerchant options hash
      def store(credit_card, options={})
        post = {}
        add_payment(post, credit_card)

        commit("/cards", post)
      end

      # Perform 3dsecure preauth with Clearhaus.
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment        - The CreditCard.
      # options        - A standard hash with
      # 
      # options:
      #       order_id: unique id of preauth transaction
      #       merchant: Hash with required :acquirer_bin, :id, :name, :country, :url keys
      #
      # Returns an ActiveMerchant::Billing::ClearhausGateway::ThreedResponse object
      def threed_auth(amount, payment, options = {})
        requires!(@options, :mpi_api_key)

        post = {}

        add_amount(post, amount, options)
        add_3d_payment(post, payment)
        add_merchant_data(post, options)
        add_additional_threed_data(post, options)
        post[:currency] = (options[:currency] || currency(amount))

        commit_3d('/enrolled', post)
      end

      def supports_scrubbing?
        false
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_3dsecure_data(post, options)
        if options.key?(:pares)
          post[:threed_secure] = {}
          post[:threed_secure][:pares] = options[:pares]
        end
      end

      def add_merchant_data(post, options)  
        requires!(options, :merchant, :order_id)      
        requires!(options[:merchant], :id, :name, :acquirer_bin, :country, :url)

        post[:order_id] = options[:order_id]
        post[:merchant] = options[:merchant]
        post[:ip] = options[:ip] if options.key?(:ip)
      end

      def add_additional_threed_data(post, options)
        post[:cardholder_ip]   = options[:ip] if options.key?(:ip)
      end

      def add_invoice(post, money, options)
        post[:reference]         = options[:order_id] if options[:order_id]
        post[:amount]            = amount(money)
        post[:currency]          = (options[:currency] || currency(money))
        post[:text_on_statement] = options[:description] if options[:description]
      end

      def add_amount(post, money, options)
        post[:amount]  = amount(money)
      end

      def add_payment(post, payment)
        card = {}
        card[:number]       = payment.number
        card[:expire_month] = '%02d'% payment.month
        card[:expire_year]  = payment.year

        if payment.verification_value?
          card[:csc]  = payment.verification_value
        end
        
        post[:card] = card if card.any?
      end

      def add_3d_payment(post, payment)
        card = {}

        card[:number] = payment.number
        card[:expire_month]  = '%02d'% payment.month
        card[:expire_year]   = payment.year        
        post[:card]   = card
      end

      def add_recurrence_mode(post, options)
        post[:recurring] = options[:recurring] if options[:recurring]
      end

      def headers(api_key)
        auth = Base64.strict_encode64("#{api_key}:")
        {
          "Authorization"  => "Basic " + auth,
          "User-Agent"     => "Clearhaus ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end

      def parse(body)
        JSON.parse(body) rescue body
      end

      def commit_3d(action, parameters)
        url = (test? ? test_mpi_url : live_mpi_url) + action

        response = begin
          parse(ssl_post(url, post_data(action, parameters), headers(@options[:mpi_api_key])))
        rescue ResponseError => e
          raise if(e.response.code.to_s =~ /401/)
          parse(e.response.body)
        end

        ThreedResponse.new(
          success_from_3d(response),
          message_from_3d(response),
          response,
          test: test?
        )
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url) + action
        req_headers = headers(@options[:api_key])
        req_body = post_data(action, parameters)

        if signing_key = @options[:signing_key]
          req_headers["Signature"] = generate_signature(@options[:api_key], signing_key, req_body)
        end

        response = begin
          parse(ssl_post(url, req_body, req_headers))
        rescue ResponseError => e
          raise if(e.response.code.to_s =~ /401/)
          parse(e.response.body)
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
        response && response['status']['code'] == 20000
      end

      def message_from(response)
        default_message = action_status_msg(response)

        if success_from(response)
          default_message
        else
          response['status']['message'] || default_message
        end
      end

      def authorization_from(response)
        response['id']
      end

      def post_data(action, parameters = {})
        parameters.to_query
      end

      def generate_signature(api_key, signing_key, body)
        key = OpenSSL::PKey::RSA.new(signing_key)
        hex = key.sign(OpenSSL::Digest.new('sha256'), body).unpack('H*').first
        
        "#{api_key} RS256-hex #{hex}"
      end

      def error_code_from(response)
        unless success_from(response)
          response['status']['code']
        end
      end

      def action_status_msg(response)
        ACTION_CODE_MESSAGES[response['status']['code']]
      end

      def success_from_3d(response)
        response.key?('enrolled') && response['enrolled'] == 'Y'
      end

      def message_from_3d(response)
        success_from_3d(response) ? 'enrolled' : response['error']
      end

      class ThreedResponse < Response
        def enrolled?
          params['enrolled'] == 'Y'
        end
      end
    end
  end
end
