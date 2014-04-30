require File.dirname(__FILE__) + '/mobikwikwallet/helper.rb'
require File.dirname(__FILE__) + '/mobikwikwallet/notification.rb'
require File.dirname(__FILE__) + '/mobikwikwallet/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Mobikwikwallet
        def self.service_url
          case ActiveMerchant::Billing::Base.integration_mode
          when :production
            'https://www.mobikwik.com/wallet'
          when :test
            'https://test.mobikwik.com/mobikwik/wallet'
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end

        def self.checksum(secret_key, payload_items)
          digest = OpenSSL::Digest.new('sha256')
          OpenSSL::HMAC.hexdigest(digest, secret_key, payload_items)
        end
      end
    end
  end
end
