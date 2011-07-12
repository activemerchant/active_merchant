if RUBY_VERSION =~ /^1\.8\./
  require 'json'
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StripeGateway < Gateway
      VERSION = '1.0.0'
      LIVE_URL = 'https://api.stripe.com/v1/'

      AVS_CODE_TRANSLATOR = {
        'line1: pass, zip: pass' => 'Y',
        'line1: pass, zip: fail' => 'A',
        'line1: pass, zip: unchecked' => 'B',
        'line1: fail, zip: pass' => 'Z',
        'line1: fail, zip: fail' => 'N',
        # AVSResult will parse this as a failed, not unchecked, street address.  Only 'F' would parse correctly, but F isn't the right text here.
        'line1: unchecked, zip: pass' => 'P',
        'line1: unchecked, zip: unchecked' => 'I'
      }

      CVC_CODE_TRANSLATOR = {
        'pass' => 'M',
        'fail' => 'N',
        'unchecked' => 'P'
      }

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      self.homepage_url = 'https://stripe.com/'
      self.display_name = 'Stripe'

      @@ua = nil

      def initialize(options = {})
        requires!(options, :login)
        @api_key = options[:login]
        super
      end

      def purchase(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        add_customer(post, options)
        add_customer_data(post, options)

        if (!post[:card] && !post[:customer])
          raise ArgumentError.new("Customer or Credit Card required.")
        elsif (post[:card] && post[:customer])
          raise ArgumentError.new("Can't provide both Customer and Credit Card.")
        end

        commit('charges', :post, post)
      end

      def void(identification, options={})
        commit("charges/#{CGI.escape(identification)}/refund", :post, {})
      end

      def store(creditcard, options={})
        post = {}
        add_creditcard(post, creditcard, options)
        add_customer_data(post, options)

        if options[:customer]
          commit("customers/#{CGI.escape(options[:customer])}", :post, post)
        else
          commit('customers', :post, post)
        end
      end

      private

      def add_amount(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money)).downcase
      end

      def add_customer_data(post, options)
        post[:description] = options[:email] || options[:description]
      end

      def add_address(post, options)
        return unless post[:card] && post[:card].kind_of?(Hash)
        if address = options[:billing_address] || options[:address]
          post[:card][:address_line1] = address[:address1] if address[:address1]
          post[:card][:address_line2] = address[:address2] if address[:address2]
          post[:card][:address_country] = address[:country] if address[:country]
          post[:card][:address_zip] = address[:zip] if address[:zip]
          post[:card][:address_state] = address[:state] if address[:state]
        end
      end

      def add_creditcard(post, creditcard, options)
        if creditcard.kind_of?(CreditCard)
          card = {}
          card[:number] = creditcard.number
          card[:exp_month] = creditcard.month
          card[:exp_year] = creditcard.year
          card[:cvc] = creditcard.verification_value if creditcard.verification_value?
          card[:name] = creditcard.name if creditcard.name
          post[:card] = card

          add_address(post, options)
        elsif creditcard.kind_of?(String)
          post[:card] = creditcard
        end
      end

      def add_customer(post, options)
        post[:customer] = options[:customer] if options[:customer]
      end

      def parse(body)
        JSON.parse(body, :symbolize_names => true)
      end

      def post_data(params)
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

      def headers
        @@ua ||= JSON.dump({
          :bindings_version => VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant',
          :uname => (RUBY_PLATFORM =~ /linux|darwin/i ? `uname -a 2>/dev/null`.strip : nil)
        })

        {
          "Authorization" => "Basic " + ActiveSupport::Base64.encode64(@api_key+":").gsub(/\n/, ''),
          "User-Agent" => "Stripe/v1 ActiveMerchantBindings/#{VERSION}",
          "X-Stripe-Client-User-Agent" => @@ua
        }
      end

      def commit(url, method, parameters)
        raw_response = response = nil
        success = false
        begin
          raw_response = ssl_request(method, LIVE_URL + url, post_data(parameters), headers)
          response = parse(raw_response)
          success = !response.key?(:error)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        card = response[:card] || {}
        avs_code = AVS_CODE_TRANSLATOR["line1: #{card[:address_line1_check]}, zip: #{card[:address_zip_check]}"]
        cvc_code = CVC_CODE_TRANSLATOR[card[:cvc_check]]
        Response.new(success,
          success ? "Transaction approved" : response[:error][:message],
          response,
          :test => !response[:livemode],
          :authorization => response[:id],
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
          :error => {
            :message => msg
          }
        }
      end
    end
  end
end
