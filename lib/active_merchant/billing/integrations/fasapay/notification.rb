require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Fasapay
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          %w(
            fp_paidto
            fp_paidby
            fp_amnt
            fp_fee_amnt
            fp_currency
            fp_batchnumber
            fp_item
            fp_store
            fp_timestamp
            fp_merchant_ref
            fp_hash
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :account, :fp_paidto
          alias_method :payer, :fp_paidby
          alias_method :amount, :fp_amnt
          alias_method :fee_amount, :fp_fee_amnt
          alias_method :currency, :fp_currency
          alias_method :description, :fp_item
          alias_method :account_name, :fp_store
          alias_method :received_at, :fp_timestamp
          alias_method :order, :fp_merchant_ref
          alias_method :item_id, :fp_merchant_ref
          alias_method :number, :fp_batchnumber
          alias_method :hash, :fp_hash

          def acknowledge
            hash == generate_signature
          end

          def generate_signature_string
            string = [
                account,
                payer,
                account_name,
                amount,
                number,
                currency,
                @options[:secret]
              ].join ':'
          end

          def generate_signature
            Digest::SHA256.hexdigest(generate_signature_string).downcase
          end

        end
      end
    end
  end
end
