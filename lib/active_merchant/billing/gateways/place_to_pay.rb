module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PlaceToPayGateway < Gateway
      attr_accessor :login, :secret_key, :current_country
      self.test_url = 'https://test.placetopay.com/rest/gateway/'
      self.live_url = 'https://secure.placetopay.com/redirection/'
      self.supported_countries = ['COL', 'EC']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners]

      self.homepage_url = 'https://www.placetopay.com/'
      self.display_name = 'PlaceToPay' 

      URL_FOR_COUNTRIES = {
        'EC': {
          'test': 'https://test.placetopay.ec/rest/gateway/',
          'prod': 'https://secure.placetopay.ec/redirection/',
        },
        'COL': {
          'test': 'https://test.placetopay.com/rest/gateway/',
          'prod': 'https://secure.placetopay.com/redirection/',
        }
      }
      COMMON_MESSAGES = {
        'missed': 'Missing error message'
      } 
      RESPONSES_STATUS = {
        'ok': 'OK',
        'approved': 'APPROVED',
        'pending': 'PENDING',
        'manual': 'MANUAL',
        'refunded': 'REFUNDED',
        'failed': 'FAILED',
        'rejected': 'REJECTED',
      }

      LIST_OF_SUPPORTED_COUNTRIES = {
        'colombia': {
          'key': 'COL',
          'locale': 'es_CO'
        },
        'ecuador': {
          'key': 'EC',
          'locale': 'es_EC'
        },
        'anotherCountry': {
          'locale': 'en_US'
        }
      }
      STANDARD_ERROR_CODE_MAPPING = {}
      BASE_COUNTRY = LIST_OF_SUPPORTED_COUNTRIES[:colombia][:key]
      STANDARD_ERROR_FOR_AUTHORIZATION = {
        '100' => 'UsernameToken not provided (authorization header 100 malformed)',
        '101' => 'Site identifier does not exist (incorrect login or not found in the 101 environment)',
        '102' => 'TranKey hash does not match (wrong or malformed Trankey)',
        '103' => 'Fecha de la semilla mayor de 5 minutos',
        '104' => 'Site inactive',
        '105' => 'Site expired',
        '106' => 'Expired credentials',
        '107' => 'Bad definition of UsernameToken (Does not comply with header 107 WSSE)',
        '200' => 'Skip SOAP Authentication Header',
        '10001' => 'Contact Support',
        'BR' => 'Contact Support',
      }

      ISO_FORMAT_DATE = '%Y-%m-%dT%H:%M:%S%:z'

      def initialize(options={})
        requires!(options, :login, :secret_key, :country)
        @login, @secret_key, @current_country = options.values_at(:login, :secret_key, :country)
        super
      end

      def authorize(money, payment, options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_instrument(post, payment)
        add_payment(post, money, options)
        commit('authonly', post)
      end

      def purchase(money, payment, options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_payment(post, money, options)
        add_instrument(post, payment)
        add_credit_information(post, options)
        add_otp(post, options)
        add_titular_data(post, options)
        add_titular_data(post, options, 'buyer')
        add_additional(post, options)
        commit('sale', post)
    end

      def my_pi_query(money, payment, options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_instrument(post, payment)
        add_payment(post, money, options)
        add_mpi_id(post, options)
        commit('mpiQuery', post)
      end

      def calculate_interests(money, payment, options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_instrument(post, payment)
        add_payment(post, money, options)
        add_credit_information(post, options)
        commit('interests', post)
      end

      def generate_otp(money, payment, options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_instrument(post, payment)
        add_payment(post, money, options)
        commit('generate_otp', post)
      end

      def validate_otp(money, payment, options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_instrument(post, payment)
        add_payment(post, money, options)
        post[:instrument][:otp] = options[:otp]
        commit('validate_otp', post)
      end

      def get_status_transaction(options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_internal_reference(post, options)
        commit('query_transaction', post)
      end

      def refund(options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_refund_action(post, options)
        commit('refund', post)
      end

      def capture(payment, options={})
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        add_titular_data(post, options)
        add_instrument(post, payment)
        post[:instrument][:otp] = options[:otp]
        commit('capture', post)
      end

      def search_transaction(money, options)
        post = {}
        add_auth(post, options)
        add_additional_data(post, options)
        post[:reference] = options[:reference]
        post[:amount] = {
          'currency': options[:amount][:currency],
          'total': amount(money)
        }
        commit('search', post)
      end

      def supports_scrubbing?
        false
      end

      # Temporary comment until resolve bug with external client
      # def lookup_card(money, payment, options={})
      #   post = {}
      #   add_auth(post, options)
      #   add_instrument(post, payment)
      #   add_payment(post, money, options)
      #   add_return_url(post, options)
      #   commit('lookup', post)
      # end

      private

      def add_otp(post, options)
        post[:otp] = options[:otp]
      end

      def add_auth(post, options)
        original_nonce = generate_nonce()
        seed = get_date_in_iso_format()
        post[:auth] = {
          'login': @login,
          'nonce': convert_to_Base64(original_nonce),
          'tranKey': generate_trans_key(original_nonce, seed),
          'seed': seed,
        }
      end

      def add_titular_data(post, options, type='payer')
        post[type] = {
          'document': options[type.to_sym][:document],
          'documentType': options[type.to_sym][:documentType],
          'name': options[type.to_sym][:name],
          'surname': options[type.to_sym][:surname],
          'email': options[type.to_sym][:email],
          'mobile': options[type.to_sym][:mobile]
        }
      end

      def add_additional(post, options)
        post[:additional] = options[:additional]
      end

      def generate_nonce
        Digest::MD5.hexdigest(rand(10).to_s)
      end

      def get_date_in_iso_format
        Time.now.strftime(ISO_FORMAT_DATE)
      end

      def convert_to_Base64(value)
        Base64.strict_encode64(value).chomp
      end

      def generate_trans_key(original_nonce, seed)
        base_tran_key = "#{original_nonce}#{seed}#{@secret_key}"
        key_to_digest = Digest::SHA256.digest(base_tran_key)
        convert_to_Base64(key_to_digest)
      end

      def add_refund_action(post, options)
        post[:internalReference] = options[:internalReference]
        post[:authorization] = options[:authorization]
        post[:action] = options[:action]
      end

      def add_instrument(post, payment)
        post[:instrument] = {
          'card': {
            'number': payment.number,
            'cvv': payment.verification_value,
            'expirationMonth': payment.month,
            'expirationYear': payment.year
          }
        }
      end

      def add_credit_information(post, options) 
        post[:instrument][:credit] = {
          'code': options[:code],
          'type': options[:type],
          'groupCode': options[:group_code],
          'installment': options[:installment]
        }
      end

      def add_payment(post, money, options)
        post[:payment] = {}
        post[:payment][:reference] = options[:reference]
        post[:payment][:description] = options[:description] if options[:description].present?
        post[:payment][:amount] = {
          'total': amount(money),
          'currency': (options[:currency] || currency(money))
        }
        add_taxes(post, options)
        add_details(post, options)
      end

      def add_taxes(post, options)
        post[:payment][:amount][:taxes] = options[:taxes] if options[:taxes].present?
      end

      def add_details(post, options)
        post[:payment][:amount][:details] = options[:details] if options[:details].present?
      end

      def add_return_url(post, options)
        post[:returnUrl] = options[:returnUrl]
      end

      def add_mpi_id(post, options)
        post[:id] = options[:id]
      end

      def add_internal_reference(post, options)
        post[:internalReference] = options[:internalReference]
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def commit(action, parameters)
        begin
          raw_response = ssl_post(url(action, parameters), post_data(action, parameters), request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end
        success = success_from(action, response, options)
        Response.new(
          success,
          message_from(response),
          response,
          test: test?,
          error_code: error_code_from(action, response, options)
        )
      end

      def success_from(action, response, options)
        case action
        when :authonly.to_s, :lookup.to_s, :mpiQuery.to_s, :interests.to_s, :generate_otp.to_s,
          :validate_otp.to_s, :capture.to_s, :search.to_s
          return response['status'] && response['status']['status'] === RESPONSES_STATUS[:ok]
        when :sale.to_s, :query_transaction.to_s, :refund.to_s
          return response['status'] && response['status']['status'] === RESPONSES_STATUS[:approved]
        else
          return response['status']['status'];
        end
      end

      def message_from(response)
        response['status'] && response['status']['message'] ? response['status']['message'] :
          COMMON_MESSAGES[:missed]
      end

      def post_data(action, parameters = {})
        JSON.generate(parameters)
      end

      def error_code_from(action, response, options)
        STANDARD_ERROR_FOR_AUTHORIZATION[response['reason']]
      end

      def url(action, options)
        country_urls = @current_country.present? ? URL_FOR_COUNTRIES[@current_country.to_sym] : URL_FOR_COUNTRIES[BASE_COUNTRY]
        siteUrl = test? ? country_urls[:test] : country_urls[:prod]
        routes = {
          'authonly': "#{siteUrl}information",
          'lookup': "#{siteUrl}mpi/lookup",
          'mpiQuery': "#{siteUrl}mpi/query",
          'interests': "#{siteUrl}interests",
          'generate_otp': "#{siteUrl}otp/generate",
          'validate_otp': "#{siteUrl}otp/validate",
          'sale': "#{siteUrl}process",
          'query_transaction': "#{siteUrl}query",
          'refund': "#{siteUrl}transaction",
          'capture': "#{siteUrl}tokenize",
          'search': "#{siteUrl}search"
        }
        routes[action.to_sym]
      end

      def request_headers(options)
        headers = {'Content-Type' => 'application/json'}
        headers
      end

      def add_additional_data(post, options)
        post[:locale] = options[:locale] || LIST_OF_SUPPORTED_COUNTRIES[:colombia][:locale]
      end
    end
  end
end
