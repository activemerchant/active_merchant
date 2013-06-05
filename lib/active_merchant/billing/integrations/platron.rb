module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      #Platron API: www.platron.ru/PlatronAPI.pdf‎
      module Platron

        autoload :Helper, File.dirname(__FILE__) + '/platron/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/platron/notification.rb'
        autoload :Common, File.dirname(__FILE__) + '/platron/common.rb'

        mattr_accessor :service_url
        self.service_url = 'https://www.platron.ru/payment.php'

        def self.notification(raw_post)
          Notification.new(raw_post)
        end

      end
    end
  end
end
