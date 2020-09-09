
require 'active_merchant/billing/gateways/paypal/paypal_common_api'
require 'active_merchant/billing/gateways/paypal_commerce_platform_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCommercePlatformGateway < Gateway
      attr_accessor :test_redirect_url
      NON_STANDARD_LOCALE_CODES = {
          'DK' => 'da_DK',
          'IL' => 'he_IL',
          'ID' => 'id_ID',
          'JP' => 'jp_JP',
          'NO' => 'no_NO',
          'BR' => 'pt_BR',
          'RU' => 'ru_RU',
          'SE' => 'sv_SE',
          'TH' => 'th_TH',
          'TR' => 'tr_TR',
          'CN' => 'zh_CN',
          'HK' => 'zh_HK',
          'TW' => 'zh_TW'
      }
     def api_adapter
       @api_adapter ||= ActiveMerchant::Billing::PaypalCommercePlatformApi.new(self)
     end

      def initialize
        self.test_redirect_url = 'https://api.sandbox.paypal.com'
      end

      self.supported_countries = ['US']
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PPCP Checkout'
      self.currencies_without_fractions = %w(HUF JPY TWD)


      delegate :post, to: :api_adapter
      delegate :patch, to: :api_adapter
    end
  end
end
