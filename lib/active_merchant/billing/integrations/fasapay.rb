require File.dirname(__FILE__) + '/fasapay/helper.rb'
require File.dirname(__FILE__) + '/fasapay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Fasapay
        mattr_accessor :service_url
        self.service_url = 'https://sci.fasapay.com'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'fp_hash'

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
