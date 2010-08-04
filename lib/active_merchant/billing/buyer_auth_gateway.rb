require 'net/http'
require 'net/https'
require 'active_merchant/billing/response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BuyerAuthGateway
      include PostsData
      include RequiresParameters
      include Utils
      
      # The format of the amounts used by the gateway
      # :dollars => '12.50'
      # :cents => '1250'
      class_inheritable_accessor :money_format
      self.money_format = :dollars
      
      # The default currency for the transactions if no currency is provided
      class_inheritable_accessor :default_currency
      
      def initialize(options = {})
      end
                                     
      # Are we running in test mode?
      def test?
        Base.gateway_mode == :test
      end
      
      private
      
      def amount(money)
        return nil if money.nil?
        cents = money.respond_to?(:cents) ? money.cents : money 

        if money.is_a?(String) or cents.to_i < 0
          raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.' 
        end

        if self.money_format == :cents
          cents.to_s
        else
          sprintf("%.2f", cents.to_f / 100)
        end
      end
      
      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end
      
    end
  end
end