require File.dirname(__FILE__) + '/yandex_money/helper.rb'
require File.dirname(__FILE__) + '/yandex_money/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module YandexMoney

        mattr_accessor :service_url
        self.service_url = 'https://money.yandex.ru/eshop.xml'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(*args)
          Notification.new(*args)
        end

      end
    end
  end
end