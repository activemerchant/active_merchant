require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on Balanced visit https://www.balancedpayments.com
    # or visit #balanced on irc.freenode.net
    #
    # Instantiate a instance of BalancedGateway by passing through your
    # Balanced API key secret.
    #
    # ==== To obtain an API key of your own
    #
    # 1. Visit https://www.balancedpayments.com
    # 2. Click "Get started"
    # 3. The next screen will give you a test API key of your own
    # 4. When you're ready to generate a production API key click the "Go
    #    live" button on the Balanced dashboard and fill in your marketplace
    #    details.
    class BalancedGateway < Gateway
      VERSION = '2.0.0'

      self.live_url = 'https://api.balancedpayments.com'

      self.supported_countries = ['US']
      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'https://www.balancedpayments.com/'
      self.display_name = 'Balanced'
      self.money_format = :cents

      # Creates a new BalancedGateway
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The Balanced API Secret (REQUIRED)
      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def purchase(money, payment_method, options = {})
        post = {}
        add_amount(post, money)
        post[:description] = options[:description]
        add_common_params(post, options)

        MultiResponse.run do |r|
          identifier =
            if payment_method.respond_to?(:number)
              r.process { store(payment_method, options) }
              r.authorization
            else
              payment_method
            end
          r.process { commit('debits', "cards/#{card_identifier_from(identifier)}/debits", post) }
        end
      end

      def authorize(money, payment_method, options = {})
        post = {}
        add_amount(post, money)
        post[:description] = options[:description]
        add_common_params(post, options)

        MultiResponse.run do |r|
          identifier =
            if payment_method.respond_to?(:number)
              r.process { store(payment_method, options) }
              r.authorization
            else
              payment_method
            end
          r.process { commit('card_holds', "cards/#{card_identifier_from(identifier)}/card_holds", post) }
        end
      end

      def capture(money, identifier, options = {})
        post = {}
        add_amount(post, money)
        post[:description] = options[:description] if options[:description]
        add_common_params(post, options)

        commit('debits', "card_holds/#{reference_identifier_from(identifier)}/debits", post)
      end

      def void(identifier, options = {})
        post = {}
        post[:is_void] = true
        add_common_params(post, options)

        commit('card_holds', "card_holds/#{reference_identifier_from(identifier)}", post, :put)
      end

      def refund(money, identifier, options = {})
        post = {}
        add_amount(post, money)
        post[:description] = options[:description]
        add_common_params(post, options)

        commit('refunds', "debits/#{reference_identifier_from(identifier)}/refunds", post)
      end

      def store(credit_card, options={})
        post = {}

        post[:number] = credit_card.number
        post[:expiration_month] = credit_card.month
        post[:expiration_year] = credit_card.year
        post[:cvv] = credit_card.verification_value if credit_card.verification_value?
        post[:name] = credit_card.name if credit_card.name

        add_address(post, options)

        commit('cards', 'cards', post)
      end

      private

      def reference_identifier_from(identifier)
        case identifier
        when %r{\|}
          uri = identifier.
                split('|').
                detect { |part| part.size > 0 }
          uri.split('/')[2]
        when %r{\/}
          identifier.split('/')[5]
        else
          identifier
        end
      end

      def card_identifier_from(identifier)
        identifier.split('/').last
      end

      def add_amount(post, money)
        post[:amount] = amount(money) if money
      end

      def add_address(post, options)
        address = (options[:billing_address] || options[:address])
        if address && address[:zip].present?
          post[:address] = {}
          post[:address][:line1] = address[:address1] if address[:address1]
          post[:address][:line2] = address[:address2] if address[:address2]
          post[:address][:city] = address[:city] if address[:city]
          post[:address][:state] = address[:state] if address[:state]
          post[:address][:postal_code] = address[:zip] if address[:zip]
          post[:address][:country_code] = address[:country] if address[:country]
        end
      end

      def add_common_params(post, options)
        post[:appears_on_statement_as] = options[:appears_on_statement_as]
        post[:on_behalf_of_uri] = options[:on_behalf_of_uri]
        post[:meta] = options[:meta]
      end

      def commit(entity_name, path, post, method=:post)
        raw_response =
          begin
            parse(
              ssl_request(
                method,
                live_url + "/#{path}",
                post_data(post),
                headers
              ))
          rescue ResponseError => e
            raise unless e.response.code.to_s =~ /4\d\d/

            parse(e.response.body)
          end

        Response.new(
          success_from(entity_name, raw_response),
          message_from(raw_response),
          raw_response,
          authorization: authorization_from(entity_name, raw_response),
          test: test?
        )
      end

      def success_from(entity_name, raw_response)
        entity = (raw_response[entity_name] || []).first
        if !entity
          false
        elsif (entity_name == 'refunds') && entity.include?('status')
          %w(succeeded pending).include?(entity['status'])
        elsif entity.include?('status')
          (entity['status'] == 'succeeded')
        elsif entity_name == 'cards'
          !!entity['id']
        else
          false
        end
      end

      def message_from(raw_response)
        if raw_response['errors']
          error = raw_response['errors'].first
          (error['additional'] || error['message'] || error['description'])
        else
          'Success'
        end
      end

      def authorization_from(entity_name, raw_response)
        entity = (raw_response[entity_name] || []).first
        (entity && entity['id'])
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        message = 'Invalid response received from the Balanced API. Please contact support@balancedpayments.com if you continue to receive this message.'
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        {
          'errors' => [{
            'message' => message
          }]
        }
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value.blank?

          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join('&')
      end

      def headers
        @@ua ||= JSON.dump(
          bindings_version: ActiveMerchant::VERSION,
          lang: 'ruby',
          lang_version: "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          lib_version: BalancedGateway::VERSION,
          platform: RUBY_PLATFORM,
          publisher: 'active_merchant'
        )

        {
          'Authorization' => 'Basic ' + Base64.encode64(@options[:login].to_s + ':').strip,
          'User-Agent' => "Balanced/v1.1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          'Accept' => 'application/vnd.api+json;revision=1.1',
          'X-Balanced-User-Agent' => @@ua
        }
      end
    end
  end
end
