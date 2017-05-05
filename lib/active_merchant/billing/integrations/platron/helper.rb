module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Platron
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            @secret_key = options.delete(:secret)
            @path = options.delete(:path)
            description = options.delete(:description)
            super
            self.add_field('pg_salt', rand(36**15).to_s(36))
            self.add_field('pg_description', description)
          end

          def form_fields
            @fields.merge('pg_sig' => Common.generate_signature(@fields, @path, @secret_key))
          end

          def params
            @fields
          end

          mapping :account, 'pg_merchant_id'
          mapping :amount, 'pg_amount'
          mapping :order, 'pg_order_id'
          mapping :description, 'pg_description'
          mapping :currency, 'pg_currency'
        end
      end
    end
  end
end
