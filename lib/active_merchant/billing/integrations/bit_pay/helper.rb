module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order_id, account, options)
            super
            @account = account
            add_field('orderID', order_id)
            add_field('posData', options[:authcode])
            add_field('currency', options[:currency])
            add_field('fullNotifications', 'true')
            add_field('transactionSpeed', options[:transactionSpeed] || "high")
            add_field('address1', options[:address1])

            generate_invoice_id
          end

          # Replace with the real mapping
          mapping :amount, 'price'

          mapping :order, 'orderID'        
          mapping :currency, 'currency'

          mapping :customer, :first_name => 'buyerName',
                             :email      => 'buyerEmail',
                             :phone      => 'buyerPhone'

          mapping :billing_address, :city     => 'buyerCity',
                                    :address1 => 'buyerAddress1',
                                    :address2 => 'buyerAddress2',
                                    :state    => 'buyerState',
                                    :zip      => 'buyerZip',
                                    :country  => 'buyerCountry'

          mapping :notify_url, 'notificationURL'
          mapping :return_url, 'returnURL'
          mapping :id, 'id'

          def generate_invoice_id
            invoice_data = ssl_post(BitPay.invoicing_url)

            add_field('id', JSON.parse(invoice_data.body)['id'])
          end

          def form_method
            "GET"
          end

          private

          def ssl_post(url, options = {})
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Post.new(uri.request_uri)
            request.content_type = "application/json"
            request.body = @fields.to_json
            request.basic_auth @account, ''

            http.request(request)
          end
        end
      end
    end
  end
end
