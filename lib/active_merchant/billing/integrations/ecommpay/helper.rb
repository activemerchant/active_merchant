module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ecommpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            @secret = options.delete(:secret)
            super
          end

          mapping :account, 'site_id'
          mapping :amount, 'amount'
          mapping :order, 'external_id'
          mapping :locale, 'language'
          mapping :currency, 'currency'
          mapping :iframe, 'iframe'
          mapping :description, 'description'
          mapping :success_url, 'success_url'
          mapping :fail_url, 'decline_url'
          mapping :callback_method, 'callback_method'
          mapping :secure_id, 'secure_id'
          mapping :payment_type_id, 'payment_type_id'
          mapping :phone, 'phone'

          def generate_signature_string
            @fields.map{|k, v| "#{k}:#{v}" }.sort.push(@secret).join(';')
          end

          def generate_signature
            Digest::SHA1.hexdigest(generate_signature_string)
          end

          def form_fields
            @fields.merge('signature' => generate_signature )
          end
        end
      end
    end
  end
end