require File.dirname(__FILE__) + '/payonline/helper.rb'
require File.dirname(__FILE__) + '/payonline/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Payonline
        mattr_accessor :service_url
        self.service_url = "https://secure.payonlinesystem.com/#{I18n.locale}/payment/"

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'SecurityKey'

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
