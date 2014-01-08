module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysera
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          API_VERSION = '1.6'

          def initialize(order, account, options = {})
            super
            @project_id = account
            @secret = options[:credential2]

            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              add_field('test', '1')
              add_field('payment', 'wallet')
            end

            add_field :version, API_VERSION
          end

          def form_fields
            parameter_hash = @fields.dup
            parameter_hash.symbolize_keys!

            # to gross cents
            parameter_hash[:amount] = (parameter_hash[:amount].to_f * 100.0).ceil

            result = {}
            result[:data] = Base64.urlsafe_encode64(combine_parameters(parameter_hash))
            result[:sign] = generate_signature_v1(result[:data], @secret)
            result
          end

          def params
            @fields
          end

          mapping :account, 'projectid'
          mapping :amount, 'amount'
          mapping :currency, 'currency'

          mapping :order, 'orderid'

          mapping :customer, :first_name => 'p_firstname',
                             :last_name  => 'p_lastname',
                             :email      => 'p_email'

          mapping :billing_address, :city     => 'p_city',
                                    :address1 => 'p_street',
                                    :state    => 'p_state',
                                    :zip      => 'p_zip',
                                    :country  => 'p_countrycode'

          mapping :notify_url, 'callbackurl'
          mapping :return_url, 'accepturl'
          mapping :cancel_return_url, 'cancelurl'
          mapping :description, 'paytext'
        end
      end
    end
  end
end
