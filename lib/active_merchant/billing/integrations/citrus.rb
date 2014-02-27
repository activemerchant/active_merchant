module ActiveMerchant
  module Billing
    module Integrations
      module Citrus
        autoload :Helper, File.dirname(__FILE__) + '/citrus/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/citrus/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/citrus/return.rb'

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.checksum(secret_key, payload_items )
          digest = OpenSSL::Digest.new('sha1')
		      OpenSSL::HMAC.hexdigest(digest, secret_key, payload_items)
        end
      end
    end
  end
end
