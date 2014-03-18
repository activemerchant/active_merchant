module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module GoCoin
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options)
            @access_token = options[:authcode]
            @currency = options[:currency] || 'USD'
            @crypto_currency = options[:crypto_currency] || 'BTC'
            @merchant_id = options[:account_name]
            super
          end

          mapping :amount, 'base_price'
          mapping :order, 'order_id'
          mapping :currency, 'base_price_currency'

          mapping :customer, :first_name => 'customer_name',
                             :email      => 'customer_email',
                             :phone      => 'customer_phone'

          mapping :billing_address, :city     => 'customer_city',
                                    :address1 => 'customer_address_1',
                                    :address2 => 'customer_address_2',
                                    :state    => 'customer_region',
                                    :zip      => 'customer_postal_code',
                                    :country  => 'customer_country'

          mapping :notify_url, 'callback_url'
          mapping :return_url, 'redirect_url'

          def form_method
            "GET"
          end

          def form_fields
            invoice = create_invoice
            raise StandardError, "Invalid response while retrieving GoCoin Invoice ID. Please try again." unless invoice
            {"invoice_id" => invoice['id']}
          end

          private

          def create_invoice
            uri = URI.parse(GoCoin.create_invoice_url(@merchant_id))
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Post.new(uri.request_uri)
            request.content_type = "application/json"
            @fields['base_price_currency'] = @currency
            @fields['price_currency'] = @crypto_currency
            request.body = @fields.to_json
            request.add_field("Authorization", "Bearer #{@access_token}")
            response = http.request(request)
            JSON.parse(response.body)
          rescue JSON::ParserError
          end
        end
      end
    end
  end
end
