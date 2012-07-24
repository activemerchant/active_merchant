module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paxum
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common

          def initialize(order, account, options = {})
            @paxum_options = options.dup
            options.delete(:description)
            options.delete(:fail_url)
            options.delete(:success_url)
            options.delete(:result_url)
            super
            add_field "button_type_id", "1"
            add_field "variables", "notify_url=#{@paxum_options[:result_url]}"
            @paxum_options.each do |key, value|
              add_field mappings[key], value
            end
          end

          def form_fields
            @fields
          end

          def params
            @fields
          end

          mapping :account, 'business_email'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          mapping :order, 'item_id'
          mapping :description, 'item_name'
          mapping :fail_url, 'cancel_url'
          mapping :success_url, 'finish_url'
          mapping :result_url, 'notify_url'
        end
      end
    end
  end
end
