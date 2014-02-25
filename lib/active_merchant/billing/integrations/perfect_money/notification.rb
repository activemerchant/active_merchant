require 'net/http'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PerfectMoney
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          %w(
            PAYEE_ACCOUNT
            PAYMENT_AMOUNT
            PAYMENT_UNITS
            PAYMENT_BATCH_NUM
            PAYER_ACCOUNT
            TIMESTAMPGMT
            ORDER_NUM
            PAYMENT_ID
            V2_HASH
          ).each do |param_name|
            define_method(param_name){ params[param_name] }
          end

          alias_method :order, :PAYMENT_ID
          alias_method :account, :PAYEE_ACCOUNT
          alias_method :amount, :PAYMENT_AMOUNT
          alias_method :currency, :PAYMENT_UNITS
          alias_method :payment_batch_num, :PAYMENT_BATCH_NUM
          alias_method :payer_account, :PAYER_ACCOUNT
          alias_method :time, :TIMESTAMPGMT

          alias_method :hash, :V2_HASH

          def acknowledge
            hash == Digest::MD5.hexdigest(generate_signature_string).upcase
          end

          #PAYMENT_ID:PAYEE_ACCOUNT:PAYMENT_AMOUNT:PAYMENT_UNITS:PAYMENT_BATCH_NUM:PAYER_ACCOUNT:AlternateMerchantPassphraseHash:TIMESTAMPGMT

          def generate_signature_string
            string = [
                order,
                account,
                amount,
                currency,
                payment_batch_num,
                payer_account,
                Digest::MD5.hexdigest(@options[:secret]).upcase,
                time
              ].join ':'
          end

        end
      end
    end
  end
end
