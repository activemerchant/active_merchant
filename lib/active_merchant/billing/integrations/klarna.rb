require File.dirname(__FILE__) + '/klarna/helper.rb'
require File.dirname(__FILE__) + '/klarna/notification.rb'
require File.dirname(__FILE__) + '/klarna/return.rb'

require 'digest'

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

          check_required_fields!(fields)
          
          payload = fields['purchase_country'].to_s + 
                    fields['purchase_currency'].to_s + 
                    fields['locale'].to_s

          cart_items.each do |item|
            payload << item.type.to_s + 
                       item.reference.to_s + 
                       item.quantity.to_s + 
                       item.unit_price.to_s

            # Part of me wants to get rid of this, but this digest will fail if
            # a discount_rate is ever passed in as a cart item property, which
            # may happen with other integrations
            if item.respond_to?(:discount_rate)
              payload << item.discount_rate.to_s
            end
          end

          payload << fields['merchant_id'].to_s +
                     fields['merchant_terms_uri'].to_s +
                     fields['merchant_checkout_uri'].to_s +
                     fields['merchant_base_uri'].to_s +
                     fields['merchant_confirmation_uri'].to_s

          payload << secret.to_s

          digest = Digest::SHA256.base64digest(payload)
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
            raise ArgumentError, "Missing required field #{required_field}" unless fields.has_key?(required_field)
          end
        end
      end
    end
  end
end
