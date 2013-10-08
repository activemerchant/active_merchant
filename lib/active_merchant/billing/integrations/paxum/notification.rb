module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paxum
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def initialize(post, options = {})
            @raw_post = post.dup
            post.slice!(0)
            super
          end

          def self.recognizes?(params)
            (params.has_key?('transaction_item_id') && params.has_key?('transaction_amount'))
          end

          def security_key
            params["key"]
          end

          def secret
            @options[:secret]
          end

          def acknowledge(authcode = nil)
            (security_key == generate_signature)
          end
        end
      end
    end
  end
end
