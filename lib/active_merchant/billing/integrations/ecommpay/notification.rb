require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ecommpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          %w( type_id
              status_id
              transaction_id
              external_id
              acquirer_id
              payment_type_id
              site_id
              amount
              currency
              real_amount
              real_currency
              email
              extended_info_enabled
              customer_purse
              completed_at
              processor_date
              source_type
              holder_name
              expiry_date
              phone
              authcode
              billing_country
              billing_region
              billing_city
              billing_address
              billing_postal
              parent_transaction_id
              recurring_allowed
              recurring_valid_thru
              recurring_registration_id
              processor_id
              processor_code
              processor_message
              signature).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :order, :external_id

          def params_select
            params.except('signature').map{|k, v| "#{k}:#{v}" if v.present? && v != 'NULL'}.compact
          end

          def amount
            params['amount'].to_i / 100.0
          end

          def acknowledge
            signature == generate_signature
          end

          def generate_signature_string
            params_select.sort.push(@options[:secret]).join(';')
          end

          def generate_signature
            Digest::SHA1.hexdigest(generate_signature_string)
          end

        end
      end
    end
  end
end
