module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dengionline

        autoload :Helper, File.dirname(__FILE__) + '/dengionline/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/dengionline/notification.rb'
        autoload :Common, File.dirname(__FILE__) + '/dengionline/common.rb'
        autoload :Status, File.dirname(__FILE__) + '/dengionline/status.rb'

        mattr_accessor :service_url
        self.service_url = 'http://www.onlinedengi.ru/wmpaycheck.php'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end

        def self.status(order, account, options = {})
          Status.new(order, account, options)
        end

      end
    end
  end
end
