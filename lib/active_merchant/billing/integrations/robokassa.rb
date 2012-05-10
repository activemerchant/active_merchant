module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      # Documentation: http://robokassa.ru/Doc/En/Interface.aspx
      module Robokassa
        autoload :Helper, File.dirname(__FILE__) + '/robokassa/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/robokassa/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/robokassa/return.rb'
        autoload :Common, File.dirname(__FILE__) + '/robokassa/common.rb'

        # Overwrite this if you want to change the Robokassa test url
        mattr_accessor :test_url
        self.test_url = 'http://test.robokassa.ru/Index.aspx'

        # Overwrite this if you want to change the Robokassa production url
        mattr_accessor :production_url
        self.production_url = 'https://merchant.roboxchange.com/Index.aspx'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'SignatureValue'

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

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
