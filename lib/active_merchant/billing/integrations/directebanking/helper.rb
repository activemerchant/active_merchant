module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Directebanking
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          # Variables that need to be set by the admin in Shopify interface
          # All credentials are mandatory and need to be set
          #
          # credential1: User ID
          # credential2: Project ID
          # credential3: Project Password (Algorithm: SH1)
          # credential4: Notification Password (Algorithm: SH1)

          def initialize(order, account, options = {})
            super
            add_field(:user_variable_1.to_s, order)
            @project_password = options[:credential3]
          end

          SIGNATURE_FIELDS = [
            :user_id,
            :project_id,
            :sender_holder,
            :sender_account_number,
            :sender_bank_code,
            :sender_country_id,
            :amount,
            :currency_id,
            :reason_1,
            :reason_2,
            :user_variable_0,
            :user_variable_1,
            :user_variable_2,
            :user_variable_3,
            :user_variable_4,
            :user_variable_5
          ]
          
          SIGNATURE_IGNORE_AT_METHOD_CREATION_FIELDS = [
            :user_id,
            :amount,
            :currency_id,
            :user_variable_1
          ]
          
          SIGNATURE_FIELDS.each do |key|
            if !SIGNATURE_IGNORE_AT_METHOD_CREATION_FIELDS.include?(key) 
              mapping "#{key}".to_sym, "#{key.to_s}"
            end
          end

          # Need to format the amount to have 2 decimal places
          def amount=(money)
            cents = money.respond_to?(:cents) ? money.cents : money
            if money.is_a?(String) or cents.to_i <= 0
              raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.'
            end
            add_field mappings[:amount], sprintf("%.2f", cents.to_f/100)
          end

          def generate_signature_string
            # format of signature: user_id|project_id|sender_holder|sender_account_number|sender_bank_code| sender_country_id|amount|currency_id|reason_1|reason_2|user_variable_0|user_variable_1| user_variable_2|user_variable_3|user_variable_4|user_variable_5|project_password
            SIGNATURE_FIELDS.map {|key| @fields[key.to_s]} * "|"+ "|"+@project_password
          end

          def generate_signature
            Digest::SHA1.hexdigest(generate_signature_string)
          end
          
          def form_fields
            @fields.merge('hash' => generate_signature)
          end
            
          # Replace with the real mapping
          mapping :account, 'user_id'
          mapping :credential2, 'project_id'
          mapping :amount, 'amount'
          mapping :currency, 'currency_id'
        end
      end
    end
  end
end
