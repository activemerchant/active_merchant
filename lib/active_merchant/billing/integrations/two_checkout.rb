module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout 
        autoload 'Helper', File.dirname(__FILE__) + '/two_checkout/helper'
        autoload 'Return', File.dirname(__FILE__) + '/two_checkout/return'
        autoload 'Notification', File.dirname(__FILE__) + '/two_checkout/notification'
       
        mattr_accessor :payment_routine
        self.payment_routine = :single_page
        
        def self.service_url
          case self.payment_routine
          when :multi_page
            'https://www.2checkout.com/checkout/purchase'  
          when :single_page
            'https://www.2checkout.com/checkout/spurchase'
          else
            raise StandardError, "Integration payment routine set to an invalid value: #{self.payment_routine}"
          end
        end
        
        def self.service_url=(service_url)
          # Note: do not use this method, it is here for backward compatibility
          # Use the payment_routine method to change service_url
          if service_url =~ /spurchase/
            self.payment_routine = :single_page
          else
            self.payment_routine = :multi_page
          end
        end
        
        
        def self.notification(post, options = {})
          Notification.new(post)
        end  
        
        def self.return(query_string, options = {})
          Return.new(query_string)
        end
      end
    end
  end
end
