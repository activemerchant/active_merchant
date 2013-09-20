module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WirecardCheckoutPage
        autoload :Common, File.dirname(__FILE__) + '/wirecard_checkout_page/common.rb'
        autoload :Helper, File.dirname(__FILE__) + '/wirecard_checkout_page/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/wirecard_checkout_page/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/wirecard_checkout_page/return.rb'

        mattr_accessor :service_url
        self.service_url = 'https://checkout.wirecard.com/page/init.php'

        def self.notification(post, options)
          Notification.new(post, options)
        end

        def self.return(postdata, options)
          Return.new(postdata, options)
        end

      end
    end
  end
end
