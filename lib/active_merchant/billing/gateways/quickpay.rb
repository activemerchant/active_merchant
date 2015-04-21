require 'rexml/document'
require 'digest/md5'

require 'active_merchant/billing/gateways/quickpay/quickpay_v10'
require 'active_merchant/billing/gateways/quickpay/quickpay_v4to7'


module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickpayGateway < Gateway
      self.abstract_class = true

      def self.new options = {}
        version = options[:version] || 10
        if version <= 7
          QuickpayV4to7Gateway.new(options)
        else
          QuickpayV10Gateway.new(options)     
        end
      end
      
    end
  end
end

