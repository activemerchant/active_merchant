module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          attr_accessor :order, :amount, :redirect_param, :account_name,
              :return_url, :notify_url, :redirect_param, :account, :account_name

          attr_reader :transaction_id

          def initialize(order, account, options = {})
            self.account_name = options.delete(:account_name)
            super

            raise ArgumentError, "The redirect_param option needs to be set to the bank_id the customer selected." if redirect_param.blank?
            raise ArgumentError, "The return_url option needs to be set." if return_url.blank?
            raise ArgumentError, "The account_name option needs to be set." if account_name.blank?
          end

          def credential_based_url
            response = request_redirect
            @transaction_id = response['id']

            uri = URI.parse(response['links']['paymentUrl'])
            set_form_fields_for_redirect(uri)
            uri.query = ''
            uri.to_s.sub(/\?\z/, '')
          end

          def form_method
            "GET"
          end

          def set_form_fields_for_redirect(uri)
            CGI.parse(uri.query).each do |key, value|
              if value.is_a?(Array) && value.length == 1
                add_field(key, value.first)
              else
                add_field(key, value)
              end
            end
          end

          def request_redirect
            request_params = {
              :amount => amount,            # In decimal notation, e.g. 123.45
              :description => account_name, # Using the name of the account name as description is not great - can we incldue an order description?
              :method => 'ideal',           # For now, this is hardcoded to be iDeal
              :issuer => redirect_param,    # Should be the issuer ID.
              :redirectUrl => return_url,
              :metadata => { :order => order }
            }

            options[:webhookUrl] = notify_url unless notify_url.blank?

            MollieIdeal.create_payment(account, request_params)
          end
        end
      end
    end
  end
end
