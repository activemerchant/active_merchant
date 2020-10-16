require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneta
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(
            MNT_ID
            MNT_TRANSACTION_ID
            MNT_OPERATION_ID
            MNT_AMOUNT
            MNT_CURRENCY_CODE
            MNT_SUBSCRIBER_ID
            MNT_TEST_MODE
            MNT_SIGNATURE
            MNT_USER
            MNT_CORRACCOUNT
            MNT_CUSTOM1
            MNT_CUSTOM2
            MNT_CUSTOM3
          ).each do |param_name|
            define_method(param_name.underscore) { params[param_name] }
          end

          alias_method :item_id, :mnt_transaction_id
          alias_method :amount, :mnt_amount

          def signature_string
            [
              mnt_id,
              mnt_transaction_id,
              mnt_operation_id,
              mnt_amount,
              mnt_currency_code,
              mnt_subscriber_id.to_i,
              mnt_test_mode.to_i,
              @options[:secret]
            ].join('')
          end

          def generate_signature
            Digest::MD5::hexdigest(signature_string).downcase
          end

          def acknowledge
            generate_signature == mnt_signature
          end

          def status; end
        end
      end
    end
  end
end
