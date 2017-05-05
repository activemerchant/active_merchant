require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epayservice
        class Notification < ActiveMerchant::Billing::Integrations::Notification
              %w( eps_request 
                  eps_trid 
                  eps_accnum 
                  eps_company 
                  eps_guid 
                  eps_amount 
                  eps_currency 
                  eps_description
                  eps_result
                  eps_sign
                ).each do |param_name|
                define_method(param_name){ params[param_name.upcase] }
              end

          alias_method :amount, :eps_amount

          def acknowledge
            result && hash
          end

          def pending
            eps_result == nil && hash
          end

          def result
            eps_result == 'done'
          end

          def hash
            eps_sign == generate_signature
          end

          def generate_signature_string
            amount + eps_guid + @options[:secret]
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string).downcase
          end
          
        end
      end
    end
  end
end
