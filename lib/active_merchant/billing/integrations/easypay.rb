module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      # Documentation: https://ssl.easypay.by/light/
      module Easypay
        autoload :Helper, File.dirname(__FILE__) + '/easypay/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/easypay/notification.rb'
        autoload :Common, File.dirname(__FILE__) + '/easypay/common.rb'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'EP_Hash'

        mattr_accessor :notify_signature_parameter_name
        self.notify_signature_parameter_name = 'notify_signature'

        mattr_accessor :service_url
        self.service_url = 'https://ssl.easypay.by/weborder/'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end
      end
    end
  end
end
