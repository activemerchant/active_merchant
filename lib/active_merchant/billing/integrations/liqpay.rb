module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      # Documentation: https://www.liqpay.com/?do=pages&p=cnb10
      module Liqpay
        autoload :Helper, File.dirname(__FILE__) + '/liqpay/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/liqpay/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/liqpay/return.rb'

        mattr_accessor :service_url
        self.service_url = 'https://liqpay.com/?do=clickNbuy'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'signature'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end

        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
