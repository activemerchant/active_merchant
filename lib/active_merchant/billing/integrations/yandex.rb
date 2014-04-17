require File.dirname(__FILE__) + '/yandex/helper.rb'
require File.dirname(__FILE__) + '/yandex/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Yandex

        mattr_accessor :service_url
        self.service_url = 'https://money.yandex.ru/eshop.xml'

        autoload :Helper, File.dirname(__FILE__) + '/yandex/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/yandex/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/yandex/return.rb'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'md5'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end

        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
