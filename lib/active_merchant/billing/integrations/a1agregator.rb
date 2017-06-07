require File.dirname(__FILE__) + '/a1agregator/helper.rb'
require File.dirname(__FILE__) + '/a1agregator/notification.rb'
require File.dirname(__FILE__) + '/a1agregator/status.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module A1agregator

        mattr_accessor :service_url
        self.service_url = 'https://partner.a1agregator.ru/a1lite/input/'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'check'

        def self.notification(*args)
          Notification.new(*args)
        end

        def self.status(login, password)
          Status.new(login, password)
        end
      end
    end
  end
end
