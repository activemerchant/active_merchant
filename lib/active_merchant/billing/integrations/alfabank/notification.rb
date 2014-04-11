require 'net/http'
require 'digest/sha1'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Alfabank
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def self.recognizes?(params)
            params.has_key?('orderId')
          end
        end
      end
    end
  end
end
