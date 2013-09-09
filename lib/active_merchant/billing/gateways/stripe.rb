require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StripeGateway < Gateway
      self.live_url = 'https://api.stripe.com/v1/'

      AVS_CODE_TRANSLATOR = {
        'line1: pass, zip: pass' => 'Y',
        'line1: pass, zip: fail' => 'A',
        'line1: pass, zip: unchecked' => 'B',
        'line1: fail, zip: pass' => 'Z',
        'line1: fail, zip: fail' => 'N',
        'line1: unchecked, zip: pass' => 'P',
        'line1: unchecked, zip: unchecked' => 'I'
      }

      CVC_CODE_TRANSLATOR = {
        'pass' => 'M',
        'fail' => 'N',
        'unchecked' => 'P'
      }

      self.supported_countries = ['US', 'CA', 'GB']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      self.homepage_url = 'https://stripe.com/'
      self.display_name = 'Stripe'

      def initialize(options = {})
        requires!(options, :login)
        @api_key = options[:login]
        @fee_refund_api_key = options[:fee_refund_login]
        super
      end

      def authorize(money, creditcard, options = {})
        post = create_post_for_auth_or_purchase(money, creditcard, options)
        post[:capture] = "false"

        commit(:post, 'charges', post, generate_meta(options))
      end

      # To create a charge on a card or a token, call
      #
      #   purchase(money, card_hash_or_token, { ... })
      #
      # To create a charge on a customer, call
      #
      #   purchase(money, nil, { :customer => id, ... })
      def purchase(money, creditcard, options = {})
        post = create_post_for_auth_or_purchase(money, creditcard, options)

        commit(:post, 'charges', post, generate_meta(options))
      end

      def capture(money, authorization, options = {})
        post = {:amount => amount(money)}
        add_application_fee(post, options)

        commit(:post, "charges/#{CGI.escape(authorization)}/capture", post)
      end

      def void(identification, options = {})
        commit(:post, "charges/#{CGI.escape(identification)}/refund", {})
      end

      def refund(money, identification, options = {})
        post = {:amount => amount(money)}
        commit_options = generate_meta(options)

        MultiResponse.run(:first) do |r|
          r.process { commit(:post, "charges/#{CGI.escape(identification)}/refund", post, commit_options) }

          return r unless options[:refund_fee_amount]

          r.process { fetch_application_fees(identification, commit_options) }
          r.process { refund_application_fee(options[:refund_fee_amount], application_fee_from_response(r), commit_options) }
        end
      end

      def application_fee_from_response(response)
        return unless response.success?

        application_fees = response.params["data"].select { |fee| fee["object"] == "application_fee" }
        application_fees.first["id"] unless application_fees.empty?
      end

      def refund_application_fee(money, identification, options = {})
        return Response.new(false, "Application fee id could not be found") unless identification

        post = {:amount => amount(money)}
        options.merge!(:key => @fee_refund_api_key)

        commit(:post, "application_fees/#{CGI.escape(identification)}/refund", post, options)
      end

      def store(creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard, options)
        post[:description] = options[:description]
        post[:email] = options[:email]

        path = if options[:customer]
          "customers/#{CGI.escape(options[:customer])}"
        else
          'customers'
        end

        commit(:post, path, post, generate_meta(options))
      end

      def update(customer_id, creditcard, options = {})
        options = options.merge(:customer => customer_id)
        store(creditcard, options)
      end

      def unstore(customer_id, options = {})
        commit(:delete, "customers/#{CGI.escape(customer_id)}", nil, generate_meta(options))
      end

      private

      def create_post_for_auth_or_purchase(money, creditcard, options)
        post = {}
        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        add_customer(post, options)
        add_customer_data(post,options)
        post[:description] = options[:description] || options[:email]
        add_flags(post, options)
        add_application_fee(post, options)
        post
      end

      def add_amount(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money)).downcase
      end

      def add_application_fee(post, options)
        post[:application_fee] = options[:application_fee] if options[:application_fee]
      end

      def add_customer_data(post, options)
        metadata_options = [:description,:browser_ip,:user_agent,:referrer]
        post.update(options.slice(*metadata_options))

        post[:external_id] = options[:order_id]
        post[:payment_user_agent] = "Stripe/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
      end

      def add_address(post, options)
        return unless post[:card] && post[:card].kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          post[:card][:address_line1] = address[:address1] if address[:address1]
          post[:card][:address_line2] = address[:address2] if address[:address2]
          post[:card][:address_country] = address[:country] if address[:country]
          post[:card][:address_zip] = address[:zip] if address[:zip]
          post[:card][:address_state] = address[:state] if address[:state]
          post[:card][:address_city] = address[:city] if address[:city]
        end
      end

      def add_creditcard(post, creditcard, options)
        card = {}
        if creditcard.respond_to?(:number)
          if creditcard.respond_to?(:track_data) && creditcard.track_data.present?
            card[:swipe_data] = creditcard.track_data
          else
            card[:number] = creditcard.number
            card[:exp_month] = creditcard.month
            card[:exp_year] = creditcard.year
            card[:cvc] = creditcard.verification_value if creditcard.verification_value?
            card[:name] = creditcard.name if creditcard.name
          end

          post[:card] = card
          add_address(post, options)
        elsif creditcard.kind_of?(String)
          if options[:track_data]
            card[:swipe_data] = options[:track_data]
          else
            card[:number] = creditcard
          end
          post[:card] = card
        end
      end

      def add_customer(post, options)
        post[:customer] = options[:customer] if options[:customer] && post[:card].blank?
      end

      def add_flags(post, options)
        post[:uncaptured] = true if options[:uncaptured]
      end

      def fetch_application_fees(identification, options = {})
        options.merge!(:key => @fee_refund_api_key)

        commit(:get, "application_fees?charge=#{identification}", nil, options)
      end

      def parse(body)
        JSON.parse(body)
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
        end.compact.join("&")
      end

      def generate_meta(options)
        {:meta => {:ip => options[:ip]}}
      end

      def headers(options = {})
        @@ua ||= JSON.dump({
          :bindings_version => ActiveMerchant::VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant',
          :uname => (RUBY_PLATFORM =~ /linux|darwin/i ? `uname -a 2>/dev/null`.strip : nil)
        })

        key = options[:key] || @api_key

        {
          "Authorization" => "Basic " + Base64.encode64(key.to_s + ":").strip,
          "User-Agent" => "Stripe/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "X-Stripe-Client-User-Agent" => @@ua,
          "X-Stripe-Client-User-Metadata" => options[:meta].to_json
        }
      end

      def commit(method, url, parameters=nil, options = {})
        raw_response = response = nil
        success = false
        begin
          raw_response = ssl_request(method, self.live_url + url, post_data(parameters), headers(options))
          response = parse(raw_response)
          success = !response.key?("error")
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        card = response["card"] || response["active_card"] || {}
        avs_code = AVS_CODE_TRANSLATOR["line1: #{card["address_line1_check"]}, zip: #{card["address_zip_check"]}"]
        cvc_code = CVC_CODE_TRANSLATOR[card["cvc_check"]]
        Response.new(success,
          success ? "Transaction approved" : response["error"]["message"],
          response,
          :test => response.has_key?("livemode") ? !response["livemode"] : false,
          :authorization => response["id"],
          :avs_result => { :code => avs_code },
          :cvv_result => cvc_code
        )
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Stripe API.  Please contact support@stripe.com if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end
    end
  end
end
