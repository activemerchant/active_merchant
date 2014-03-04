require File.dirname(__FILE__) + '/klarna/helper.rb'
require File.dirname(__FILE__) + '/klarna/notification.rb'
require File.dirname(__FILE__) + '/klarna/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna

        mattr_accessor :service_url
        self.service_url = 'https://hpp-staging-eu.herokuapp.com/api/v1/checkout'

        def self.notification(post)
          Notification.new(post)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.sign(fields, cart_items, secret)
          raise ArgumentError, "A secret is required to sign" if secret.blank?
          
          payload = ['purchase_country', 'purchase_currency', 'locale'].inject("") do |s, field_name|
            s += fields[field_name].to_s
          end

          cart_items.each do |item|
            payload << ['type', 'reference', 'quantity', 'unit_price', 'tax_rate'].inject("") do |s, field_name|
              s += item[field_name].to_s
            end
          end

          payload << ['merchant_id', 'merchant_terms_url', 'merchant_push_uri'].inject("") do |s, field_name|
            s += fields[field_name].to_s
          end

          digest = Digest::SHA256.hexdigest(secret.to_s + payload.to_s)
        end
      end
    end
  end
end
