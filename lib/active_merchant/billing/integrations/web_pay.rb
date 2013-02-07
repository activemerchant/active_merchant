module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      # Documentation: You will get it after registration steps here:
      # http://reg.webpay.by/registration-form.php
      module WebPay
        autoload :Helper, File.dirname(__FILE__) + '/web_pay/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/web_pay/notification.rb'
        autoload :Common, File.dirname(__FILE__) + '/web_pay/common.rb'

        # Overwrite this if you want to change the WebPay sandbox url
        mattr_accessor :test_url
        self.test_url = 'https://secure.sandbox.webpay.by:8843'

        # Overwrite this if you want to change the WebPay production url
        mattr_accessor :production_url
        self.production_url = 'https://secure.webpay.by'

        mattr_accessor :signature_parameter_name
        self.signature_parameter_name = 'wsb_signature'

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
      end
    end
  end
end
