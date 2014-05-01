module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          attr_reader :transaction_id, :redirect_paramaters, :token

          def initialize(order, account, options = {})
            @token = account
            @redirect_paramaters = {
              :amount => options[:amount],
              :description => options[:description],
              :issuer => options[:redirect_param],
              :redirectUrl => options[:return_url],
              :method => 'ideal',
              :metadata => { :order => order }
            }

            @redirect_paramaters[:webhookUrl] = options[:notify_url] if options[:notify_url]

            super

            raise ArgumentError, "The redirect_param option needs to be set to the bank_id the customer selected." if options[:redirect_param].blank?
            raise ArgumentError, "The return_url option needs to be set." if options[:return_url].blank?
            raise ArgumentError, "The description option needs to be set." if options[:description].blank?
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
            MollieIdeal.create_payment(token, redirect_paramaters)
          rescue ResponseError => e
            if e.response.code == '422'
              error = JSON.parse(e.response.body)['error']['message']
              raise ActionViewHelperError, error
            else
              raise
            end
          end
        end
      end
    end
  end
end
