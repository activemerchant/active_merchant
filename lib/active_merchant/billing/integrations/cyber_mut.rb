require File.dirname(__FILE__) + '/cyber_mut/helper.rb'
require File.dirname(__FILE__) + '/cyber_mut/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CyberMut

        # Overwrite this if you want to change the CyberMut test url
        mattr_accessor :test_url
        self.test_url = 'https://paiement.creditmutuel.fr/test/paiement.cgi'

        # Overwrite this if you want to change the CyberMut production url
        mattr_accessor :production_url
        self.production_url = 'https://ssl.paiement.cic-banques.fr/paiement.cgi'

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

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
