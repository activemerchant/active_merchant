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

      def json_error(raw_response)
        msg = 'Invalid response received from the WebPay API.  Please contact support@webpay.jp if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def headers(meta={})
        @@ua ||= JSON.dump({
          :bindings_version => ActiveMerchant::VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant',
          :uname => (RUBY_PLATFORM =~ /linux|darwin/i ? `uname -a 2>/dev/null`.strip : nil)
        })

        {
          "Authorization" => "Basic " + Base64.encode64(@api_key.to_s + ":").strip,
          "User-Agent" => "Webpay/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "X-Webpay-Client-User-Agent" => @@ua,
          "X-Webpay-Client-User-Metadata" => meta.to_json
        }
      end
    end
  end
end
