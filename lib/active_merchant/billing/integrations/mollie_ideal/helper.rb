module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            @order           = order
            @account         = account
            @fields          = {}
            @raw_html_fields = []
            @options         = options
            @mappings        = {}

            raise ArgumentError, "The redirect_param option needs to be set to the bank_id the customer selected." if @options[:redirect_param].blank?
            raise ArgumentError, "The return_url option needs to be set." if @options[:return_url].blank?
            raise ArgumentError, "The account_name option needs to be set." if @options[:account_name].blank?
          end

          def credential_based_url
            uri = request_redirect_uri
            set_form_fields_from_uri(uri)
            uri.query = ''
            uri.to_s.sub(/\?\z/, '')
          end

          def form_method
            "GET"
          end

          def set_form_fields_from_uri(uri)
            CGI.parse(uri.query).each do |key, value|
              if value.is_a?(Array) && value.length == 1
                @fields[key] = value.first
              else
                @fields[key] = value
              end
            end
          end

          def request_redirect_uri
            response = MollieIdeal.create_payment(@account,

              # In decimal notation, e.g. 123.45
              :amount => @options[:amount],

              # Using the name of the account name as description is not great - can we incldue an order description?
              :description => @options[:account_name],

              # For now, this is hardcoded to be iDeal
              :method => 'ideal',
              :issuer => @options[:redirect_param],

              :redirectUrl => @options[:return_url],
              :metadata => { :order => order }
            )

            URI.parse(response['links']['paymentUrl'])
          end
        end
      end
    end
  end
end
