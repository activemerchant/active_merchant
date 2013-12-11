require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WebpayGateway < StripeGateway
      self.live_url = 'https://api.webpay.jp/v1/'

      self.supported_countries = ['JP']
      self.default_currency = 'JPY'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :diners_club]

      self.homepage_url = 'https://webpay.jp/'
      self.display_name = 'WebPay'

      def capture(money, authorization, options = {})
        post = {:amount => localized_amount(money)}
        add_application_fee(post, options)
        commit(:post, "charges/#{CGI.escape(authorization)}/capture", post)
      end

      def refund(money, identification, options = {})
        post = {:amount => localized_amount(money)}
        commit_options = generate_meta(options)

        MultiResponse.run do |r|
          r.process { commit(:post, "charges/#{CGI.escape(identification)}/refund", post, commit_options) }

          return r unless options[:refund_fee_amount]

          r.process { fetch_application_fees(identification, commit_options) }
          r.process { refund_application_fee(options[:refund_fee_amount], application_fee_from_response(r), commit_options) }
        end
      end

      def refund_fee(identification, options, meta)
        raise NotImplementedError.new
      end

      def localized_amount(money, currency = self.default_currency)
        non_fractional_currency?(currency) ? (amount(money).to_f / 100).floor : amount(money)
      end

      def add_amount(post, money, options)
        post[:currency] = (options[:currency] || currency(money)).downcase
        post[:amount] = localized_amount(money, post[:currency].upcase)
      end

      def add_customer(post, creditcard, options)
        post[:customer] = options[:customer] if options[:customer] && !creditcard.respond_to?(:number)
      end

      def store(creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard, options)
        post[:description] = options[:description]
        post[:email] = options[:email]

        commit_options = generate_options(options)
        if options[:customer]
          MultiResponse.run(:first) do |r|
            r.process { commit(:post, "customers/#{CGI.escape(options[:customer])}/", post, commit_options) }

            return r unless options[:set_default] and r.success? and !r.params["id"].blank?

            r.process { update_customer(options[:customer], :default_card => r.params["id"]) }
          end
        else
          commit(:post, 'customers', post, commit_options)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the WebPay API.  Please contact support@webpay.jp if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def headers(options = {})
        @@ua ||= JSON.dump({
          :bindings_version => ActiveMerchant::VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant'
        })

        {
          "Authorization" => "Basic " + Base64.encode64(@api_key.to_s + ":").strip,
          "User-Agent" => "Webpay/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "X-Webpay-Client-User-Agent" => @@ua,
          "X-Webpay-Client-User-Metadata" => options[:meta].to_json
        }
      end
    end
  end
end
