require File.dirname(__FILE__) + '/paybox_system/helper.rb'
require File.dirname(__FILE__) + '/paybox_system/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayboxSystem

        mattr_accessor :test_url
        self.test_url = 'https://preprod-tpeweb.paybox.com/cgi/MYchoix_pagepaiement.cgi'

        mattr_accessor :production_url
        self.production_url = 'https://tpeweb.paybox.com/cgi/MYchoix_pagepaiement.cgi'

        def self.service_url
          case ActiveMerchant::Billing::Base.mode
          when :production
            self.production_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
