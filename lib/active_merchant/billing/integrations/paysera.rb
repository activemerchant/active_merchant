module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysera
        autoload :Helper, File.dirname(__FILE__) + '/paysera/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/paysera/notification.rb'
        autoload :Common, File.dirname(__FILE__) + '/paysera/common.rb'

        mattr_accessor :service_url
        self.service_url = 'https://paysera.com/pay'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end
      end
    end
  end
end
