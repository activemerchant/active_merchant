require File.dirname(__FILE__) + '/moneta/helper.rb'
require File.dirname(__FILE__) + '/moneta/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneta

        mattr_accessor :service_url
        # self.service_url = 'https://demo.moneta.ru/assistant.htm'
        self.service_url = 'https://www.payanyway.ru/assistant.htm'

        # mattr_accessor :signature_parameter_name
        # self.signature_parameter_name = 'SecurityKey'

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
