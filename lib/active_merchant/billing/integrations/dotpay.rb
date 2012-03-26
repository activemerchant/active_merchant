module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dotpay
        autoload :Return,       File.dirname(__FILE__) + '/dotpay/return.rb'
        autoload :Helper,       File.dirname(__FILE__) + '/dotpay/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/dotpay/notification.rb'

        mattr_accessor :service_url
        self.service_url = 'https://ssl.dotpay.pl'

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
