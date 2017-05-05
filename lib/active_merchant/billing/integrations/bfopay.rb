require File.dirname(__FILE__) + '/bfopay/helper.rb'
require File.dirname(__FILE__) + '/bfopay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Bfopay
        # mattr_accessor :service_url
        # self.service_url = 'http://tgw.bfopay.com/payindex'

        mattr_accessor :service_url
        self.service_url = 'https://gw.bfopay.com/payindex'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'Md5Sign'

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
