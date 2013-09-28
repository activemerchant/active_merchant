module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dengionline

        autoload :Helper, File.dirname(__FILE__) + '/dengionline/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/dengionline/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/dengionline/return.rb'
        autoload :Common, File.dirname(__FILE__) + '/dengionline/common.rb'

        mattr_accessor :service_url
        self.service_url = 'http://www.onlinedengi.ru/wmpaycheck.php'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end

        def self.checker(query_string, options = {})
          Notification.new(query_string, options)
        end

        def self.return(query_string)
          Return.new(query_string)
        end

      end
    end
  end
end
