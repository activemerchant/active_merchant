require 'time'
require 'date'
require "active_merchant/billing/model"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # A +Cryptogram+ object represents a payment reference like an ApplePay token or Stripe token
    class Cryptogram < Model
      attr_reader :encrypted_data, :description, :brand

      def self.from_apple_pay(payment_data, payment_instrument_name, payment_network)
        ApplePay.new(payment_data, description: payment_instrument_name, brand: payment_network, transaction_id)
      end

      def initialize(encrypted_data, options={})
        @encrypted_data = encrypted_data
        @description = options[:description]
        @brand = options[:brand]
      end
    end

    class ApplePay < Cryptogram
    end
  end
end