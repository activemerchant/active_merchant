module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Webmoney
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          def initialize(order, account, options = {})
            @webmoney_options = options.dup
            options.delete(:description)
            options.delete(:fail_url)
            options.delete(:success_url)
            options.delete(:result_url)
            super
            @webmoney_options.each do |key, value|
              add_field mappings[key], value
            end
          end

          def form_fields
            @fields
          end

          def params
            @fields
          end

          mapping :account, 'LMI_PAYEE_PURSE'
          mapping :amount, 'LMI_PAYMENT_AMOUNT'
          mapping :order, 'LMI_PAYMENT_NO'
          mapping :description, 'LMI_PAYMENT_DESC'
          mapping :fail_url, 'LMI_FAIL_URL'
          mapping :success_url, 'LMI_SUCCESS_URL'
          mapping :result_url, 'LMI_RESULT_URL'
        end
      end
    end
  end
end
