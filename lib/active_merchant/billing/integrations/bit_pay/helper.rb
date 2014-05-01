module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order_id, account, options)
            super
            @account = account

            add_field('posData', {'orderId' => order_id}.to_json)
            add_field('fullNotifications', true)
            add_field('transactionSpeed', 'high')
          end

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
          mapping :return_url, 'redirectURL'
          mapping :id, 'id'

          def form_method
            "GET"
          end

          def form_fields
            invoice = create_invoice

            raise ActionViewHelperError, "Invalid response while retrieving BitPay Invoice ID. Please try again." unless invoice

            {"id" => invoice['id']}
          end

          private

          def create_invoice
            uri = URI.parse(BitPay.invoicing_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Post.new(uri.request_uri)
            request.content_type = "application/json"
            request.body = @fields.to_json
            request.basic_auth @account, ''

            response = http.request(request)
            JSON.parse(response.body)
          rescue JSON::ParserError
          end
        end
      end
    end
  end
end
