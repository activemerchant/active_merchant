require File.dirname(__FILE__) + '/pay_vector/helper.rb'
require File.dirname(__FILE__) + '/pay_vector/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayVector

        mattr_accessor :service_url
        self.service_url = 'https://mms.iridiumcorp.net/Pages/PublicPages/PaymentForm.aspx'

        def self.notification(post, options = {})
          Notification.new(post, options)
        end
      end
    end
  end
end
