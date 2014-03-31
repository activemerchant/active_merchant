require File.dirname(__FILE__) + '/universal/helper.rb'
require File.dirname(__FILE__) + '/universal/notification.rb'
require File.dirname(__FILE__) + '/universal/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Universal
        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.sign(fields, key)
          Digest::HMAC.hexdigest(fields.sort.join, key, Digest::SHA256)
        end
      end
    end
  end
end
