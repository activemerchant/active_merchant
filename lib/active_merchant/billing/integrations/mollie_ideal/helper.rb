module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            @account         = account
            @fields          = {}
            @raw_html_fields = []
            @options         = options
            @mappings        = {}
            @order           = order

            raise ArgumentError, "The redirect_param option needs to be set to the bank_id the customer selected." if @options[:redirect_param].blank?
            raise ArgumentError, "The notify_url option needs to be set." if @options[:notify_url].blank?
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
            xml = MollieIdeal.mollie_api_request(:fetch,
              :partnerid   => @account,
              :bank_id     => @options[:redirect_param],
              :amount      => @options[:amount].is_a?(Money) ? @options[:amount].cents : @options[:amount],

              # Using the name of the account name as description is not great - can we incldue an order description?
              :description => @options[:account_name],

              # We append this to the return URL, because Mollie doens't return an
              # external identifier in its response that can be used to lookup the order.
              :reporturl   => append_get_parameter(@options[:notify_url], :item_id, @order),
              :returnurl   => @options[:return_url]
            )

            url = MollieIdeal.extract_response_parameter(xml, 'URL')
            raise ActiveMerchant::Billing::Error, "Did not receive a redirect URL from Mollie." if url.blank?

            URI.parse(url)
          end

          def append_get_parameter(uri, key, value)
            if uri.include?('?')
              uri + "&#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
            else
              uri + "?#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
            end
          end
        end
      end
    end
  end
end
