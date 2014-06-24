require 'digest/sha2'
require 'bigdecimal'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn
        autoload :Return, 'active_merchant/billing/integrations/payu_in/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/payu_in/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/payu_in/notification.rb'

        mattr_accessor :test_url
        mattr_accessor :production_url

        self.test_url = 'https://test.payu.in/_payment.php'
        self.production_url = 'https://secure.payu.in/_payment.php'

        def self.service_url
          ActiveMerchant::Billing::Base.integration_mode == :production ? self.production_url : self.test_url
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end

        def self.checksum(merchant_id, secret_key, *payload_items )
          options = payload_items.pop if Hash === payload_items.last
          options ||= {}
          payload = if options[:reverse] then
            payload_items.dup.push( merchant_id || "" ).unshift( secret_key || "" ).collect{ |x| x.to_s }.join("|")
          else
            payload_items.dup.unshift( merchant_id || "" ).push( secret_key || "" ).collect{ |x| x.to_s }.join("|")
          end
          Digest::SHA512.hexdigest( payload )
        end
      end
    end
  end
end
