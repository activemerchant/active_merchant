module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardPointeGateway < Gateway
      self.test_url = 'https://fts.cardconnect.com:6443/cardconnect/rest/'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb]

      self.homepage_url = 'https://cardconect.com/integrate'
      self.display_name = 'CardPointe'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :username, :password, :merchid)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_purchase(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('auth', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('auth', post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        add_retref(post, authorization)
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        add_retref(post, authorization)
        commit('refund', post)
      end

      def void(authorization, options={})
        post = {}
        add_retref(post, authorization)
        commit('void', post)
      end

      def verify(credit_card, options={})
        post = {}
        add_invoice(post, 0, options)
        add_payment(post, credit_card)
        add_address(post, credit_card, options)
        add_customer_data(post, options)

        commit('auth', post)
      end

      def store(payment, options={})
        post = {}
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_default_account(post)

        commit('profile', post)
      end

      def update(profile, payment, options = {})
        post = {}
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)
        add_default_account(post)
        add_profile(post, profile)

        commit('profile', post)
      end

      def unstore(profile, options = {})
        parameters = {}
        add_profile_parameters(parameters, profile)

        commit('delete_profile', parameters)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("account\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("merchid\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("expiry\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvv2\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        address = billing_address(options)
        post[:name] = address[:name]
        post[:phone] = address[:phone]
        post[:email] = options[:email]
      end

      def add_address(post, creditcard, options)
        address = billing_address(options)
        post[:address] = address[:address1]
        post[:city] = address[:city]
        post[:postal] = address[:zip]
        post[:region] = address[:state]
        post[:country] = address[:country]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:orderid] = options[:order_id]
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          post[:profile] = payment
        else
          post[:expiry] = "#{payment.month}/#{payment.year}"
          post[:account] = payment.number
          post[:cvv2] = payment.verification_value
        end
      end

      # Sets flag to automatically capture after authorize
      def add_purchase(post)
        post[:capture] = 'Y'
      end

      # Sets flag to make create/update account the default account
      def add_default_account(post)
        post[:defaultacct] = 'Y'
      end

      # Adds profile to post and sets update flag
      def add_profile(post, profile)
        post[:profile] = profile
        post[:profileupdate] = 'Y'
      end

      # Parses profileid and acctid from profile, and adds it parameters, used for profile deletion
      def add_profile_parameters(parameters, profile)
        profileid, acctid = profile.split('/')
        parameters[:profileid] = profileid
        parameters[:acctid] = acctid
      end

      def add_retref(post, authorization)
        post[:retref] = authorization
      end

      def billing_address(options)
        options[:billing_address] || options[:address] || {}
      end

      def parse(body)
        JSON.parse(body)
      end

      def basic_auth
        Base64.strict_encode64("#{@options[:username]}:#{@options[:password]}")
      end

      def headers
        {
          'Content-type'  => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
      end

      def commit(action, parameters)
        begin
          base_url = (test? ? test_url : live_url)

          if action.to_s == 'delete_profile'
            url = "#{base_url}profile/#{parameters[:profileid]}/#{parameters[:acctid]}/#{@options[:merchid]}"
            response = parse(ssl_request(:delete, url, nil, headers))
          else
            url = base_url + action.to_s
            response = parse(ssl_post(url, post_data(action, parameters), headers))
          end
        rescue ResponseError => e
          # raise unless(e.response.code.to_s =~ /4\d\d/)
          raise unless e.response.code.to_i.between?(400, 499)
          response = { 'resptext' => e.response.message, 'code' => e.response.code }
        end
        Response.new(
          success_from(action, response),
          message_from(response),
          response,
          authorization: authorization_from(action, response),
          avs_result: AVSResult.new(code: response['avsresp']),
          cvv_result: CVVResult.new(response['cvvresp']),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def success_from(action, response)
        case action.to_s
        when 'void'
          response['authcode'] == 'REVERS'
        else
          response['respstat'] == 'A'
        end
      end

      def message_from(response)
        response['resptext']
      end

      def authorization_from(action, response)
        case action.to_s
        when 'auth', 'refund'
          response['retref']
        when 'profile'
          "#{response['profileid']}/#{response['acctid']}"
        end
      end

      def add_merchid(post)
        post[:merchid] = @options[:merchid]
      end

      def post_data(action, parameters = {})
        add_merchid(parameters)
        JSON.generate(parameters)
      end

      def error_code_from(action, response)
        unless success_from(action, response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
