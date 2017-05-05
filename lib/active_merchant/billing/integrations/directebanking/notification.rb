module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Directebanking
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          
          def initialize(data, options)
            if options[:credential4].nil?
              raise ArgumentError, "You need to provide the notification password (SH1) as the option :credential4 to verify that the notification originated from Directebanking (Payment Networks AG)"
            end
            super
          end
          
          def complete?
            status == 'Completed'
          end
          
          def item_id
            params['user_variable_0']
          end
          
          def transaction_id
            params['transaction']
          end
          
          # When was this payment received by the client. 
          def received_at
            Time.parse(params['created']) if params['created']
          end
          
          # the money amount we received in X.2 decimal.
          def gross
            "%.2f" % params['amount'].to_f
          end

          def status
            'Completed'
          end

          def currency
            params['currency_id']
          end
          
          def test?
            params['sender_bank_name'] == 'Testbank'
          end
          
          # for verifying the signature of the URL parameters
          PAYMENT_HOOK_SIGNATURE_FIELDS = [
            :transaction,
            :user_id,
            :project_id,
            :sender_holder,
            :sender_account_number,
            :sender_bank_code,
            :sender_bank_name,
            :sender_bank_bic,
            :sender_iban,
            :sender_country_id,
            :recipient_holder,
            :recipient_account_number,
            :recipient_bank_code,
            :recipient_bank_name,
            :recipient_bank_bic,
            :recipient_iban,
            :recipient_country_id,
            :international_transaction,
            :amount,
            :currency_id,
            :reason_1,
            :reason_2,
            :security_criteria,
            :user_variable_0,
            :user_variable_1,
            :user_variable_2,
            :user_variable_3,
            :user_variable_4,
            :user_variable_5,
            :created
          ]
          
          PAYMENT_HOOK_IGNORE_AT_METHOD_CREATION_FIELDS = [
            :transaction,
            :amount,
            :currency_id,
            :user_variable_0,
            :user_variable_1,
            :user_variable_2,
            :user_variable_3,
            :created
          ]
          
          # Provide access to raw fields
          PAYMENT_HOOK_SIGNATURE_FIELDS.each do |key|
            if !PAYMENT_HOOK_IGNORE_AT_METHOD_CREATION_FIELDS.include?(key) 
              define_method(key.to_s) do
                 params[key.to_s]
              end
            end
          end
          
          def generate_signature_string
            #format is: transaction|user_id|project_id|sender_holder|sender_account_number|sender_bank_code|sender_bank_name|sender_bank_bic|sender_iban|sender_country_id|recipient_holder|recipient_account_number|recipient_bank_code|recipient_bank_name|recipient_bank_bic|recipient_iban|recipient_country_id|international_transaction|amount|currency_id|reason_1|reason_2|security_criteria|user_variable_0|user_variable_1|user_variable_2|user_variable_3|user_variable_4|user_variable_5|created|notification_password
            PAYMENT_HOOK_SIGNATURE_FIELDS.map {|key| params[key.to_s]} * "|" + "|#{@options[:credential4]}"
          end

          def generate_signature
            Digest::SHA1.hexdigest(generate_signature_string)
          end
          
          def acknowledge(authcode = nil)
            # signature_is_valid?
            generate_signature.to_s == params['hash'].to_s
          end

        end
      end
    end
  end
end
