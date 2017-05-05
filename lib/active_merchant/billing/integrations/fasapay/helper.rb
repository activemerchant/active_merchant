module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Fasapay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
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

          mapping :account, 'fp_acc'
          mapping :amount, 'fp_amnt'
          mapping :account_name, 'fp_store'
          mapping :description, 'fp_item'
          mapping :currency, 'fp_currency'
          mapping :transaction_type, 'fp_fee_mode'
          mapping :status_url, 'fp_status_url'
          mapping :success_url, 'fp_success_url'
          mapping :fail_url, 'fp_fail_url'
          mapping :status_method, 'fp_status_method'
          mapping :success_method, 'fp_success_method'
          mapping :fail_method, 'fp_fail_method'
          mapping :order, 'fp_merchant_ref'
        end
      end
    end
  end
end