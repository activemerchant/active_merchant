require File.dirname(__FILE__) + '/yandex_money/helper.rb'
require File.dirname(__FILE__) + '/yandex_money/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module YandexMoney

        # Start integration with yandex.money here: 
        # https://money.yandex.ru/start/

        # Shop example:
        # https://github.com/yandex-money/shopify-active-merchant-shop-example

        mattr_accessor :production_url, :test_url

        self.production_url = 'https://money.yandex.ru/eshop.xml'
        self.test_url = 'https://demomoney.yandex.ru/eshop.xml'

        def self.service_url
          case ActiveMerchant::Billing::Base.integration_mode
          when :production
            self.production_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
