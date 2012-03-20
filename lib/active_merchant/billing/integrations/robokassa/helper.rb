module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Robokassa
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          def initialize(order, account, options = {})
            @md5secret = options.delete(:secret)
            super
          end

          def form_fields
            @fields.merge(ActiveMerchant::Billing::Integrations::Robokassa.signature_parameter_name => generate_signature)
          end

          def main_params
            [:account, :amount, :order].map {|key| @fields[mappings[key]]}
          end

          def params
            @fields
          end

          def secret
            @md5secret
          end

          def method_missing(method_id, *args)
            method_id = method_id.to_s.gsub(/=$/, '')

            # support for robokassa custom parameters
            if method_id =~ /^shp/
              add_field method_id, args.last
            end

            super
          end

          mapping :account, 'MrchLogin'
          mapping :amount, 'OutSum'
          mapping :currency, 'IncCurrLabel'
          mapping :order, 'InvId'
          mapping :description, 'Desc'
          mapping :email, 'Email'
        end
      end
    end
  end
end
