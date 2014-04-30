require File.dirname(__FILE__) + '/klarna/helper.rb'
require File.dirname(__FILE__) + '/klarna/notification.rb'
require 'digest'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        mattr_accessor :service_url
        self.service_url = 'https://api.hostedcheckout.io/api/v1/checkout'

        def self.notification(post_body, options = {})
          Notification.new(post_body, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.cart_items_payload(fields, cart_items)
          check_required_fields!(fields)
          
          payload = fields['purchase_country'].to_s + 
                    fields['purchase_currency'].to_s + 
                    fields['locale'].to_s

          cart_items.each_with_index do |item, i|
            payload << fields["cart_item-#{i}_type"].to_s +
                       fields["cart_item-#{i}_reference"].to_s +
                       fields["cart_item-#{i}_quantity"].to_s +
                       fields["cart_item-#{i}_unit_price"].to_s +
                       fields.fetch("cart_item-#{i}_discount_rate", '').to_s
          end

          payload << fields['merchant_id'].to_s +
                     fields['merchant_terms_uri'].to_s +
                     fields['merchant_checkout_uri'].to_s +
                     fields['merchant_base_uri'].to_s +
                     fields['merchant_confirmation_uri'].to_s

          payload
        end

        def self.sign(fields, cart_items, shared_secret)
          payload = cart_items_payload(fields, cart_items)

          digest(payload, shared_secret)
        end

        def self.digest(payload, shared_secret)
          Digest::SHA256.base64digest(payload + shared_secret.to_s)
        end

        private

        def self.check_required_fields!(fields)
          %w(purchase_country 
             purchase_currency
             locale
             merchant_id
             merchant_terms_uri
             merchant_checkout_uri
             merchant_base_uri
             merchant_confirmation_uri).each do |required_field|
            raise ArgumentError, "Missing required field #{required_field}" if fields[required_field].nil?
          end
        end
      end
    end
  end
end
