require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Interkassa
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          %w(
            ik_co_id
            ik_pm_no
            ik_desc
            ik_pw_via
            ik_am
            ik_cur
            ik_inv_id
            ik_co_prs_id
            ik_trn_id
            ik_inv_crt
            ik_inv_prc
            ik_inv_st
            ik_ps_price
            ik_co_rfn
            ik_sign
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :account, :ik_co_id
          alias_method :payment_nomber, :ik_pm_no
          alias_method :description, :ik_desc
          alias_method :payment_system, :ik_pw_via
          alias_method :amount, :ik_am
          alias_method :currency, :ik_cur
          alias_method :invoice_id, :ik_inv_id
          alias_method :checkout_purse_id, :ik_co_prs_id
          alias_method :transaction_id, :ik_trn_id
          alias_method :creata_time, :ik_inv_crt
          alias_method :process_time, :ik_inv_prc
          alias_method :invoice_state, :ik_inv_st
          alias_method :paysystem_price, :ik_ps_price
          alias_method :checkout_refund, :ik_co_rfn
          alias_method :signature, :ik_sign

          def acknowledge
            signature == generate_signature
          end

          def generate_signature_string
            string = [
                amount,
                account,
                checkout_purse_id,
                checkout_refund,
                currency,
                description,
                creata_time,
                invoice_id,
                process_time,
                invoice_state,
                payment_nomber,
                paysystem_price,
                payment_system,
                transaction_id,
                @options[:secret]
              ].join ':'
          end

          def generate_signature
            Digest::MD5.base64digest(generate_signature_string)
          end
        end
      end
    end
  end
end