require 'digest/md5'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module FocalPayment
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def generate_signature_string
            string = "#{@options[:secret]}#{trans_id}#{amount}"
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string)
          end
          mapping :account, 'Merchant'
          mapping :order, 'TransRef'
          mapping :product, 'Product'
          mapping :payment_type, 'PaymentType'
          mapping :attempt_mode, 'AttemptMode'
          mapping :test_trans, 'TestTrans'
          mapping :email, 'customer[email]'
          mapping :first_name, 'customer[first_name]'
          mapping :last_name, 'customer[last_name]'
          mapping :country,  'customer[country]'
          mapping :amount, 'Amount'
          mapping :currency, 'Currency'
          mapping :site, 'Site'
        end
      end
    end
  end
end