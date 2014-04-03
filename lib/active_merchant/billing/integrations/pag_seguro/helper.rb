require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PagSeguro
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order_id, account, options)
            super
            @account = account

            add_field('itemAmount1', sprintf("%0.02f", options[:amount]))
            add_field('itemId1', '1')
            add_field('itemQuantity1', '1')
            add_field('shippingType', '3')
            add_field('currency', 'BRL')
          end

          mapping :account, 'email'
          mapping :credential2, 'token'
        
          mapping :order, 'reference'

          mapping :billing_address, :city     => 'shippingAddressDistrict',
                                    :address1 => 'shippingAddressStreet',
                                    :address2 => 'shippingAddressNumber',
                                    :state    => 'shippingAddressState',
                                    :zip      => 'shippingAddressPostalCode',
                                    :country  => 'shippingAddressCountry'

          mapping :notify_url, 'notificationURL'
          mapping :return_url, 'redirectURL'
          mapping :description, 'itemDescription1'

          def form_fields
            invoice_id = fetch_token

            {"code" => invoice_id}
          end

          def shipping(value)
            add_field("shippingCost", sprintf("%0.02f", value))
          end

          def customer(params = {})
            add_field("senderPhone", params[:phone])
            add_field("senderEmail", params[:email])
            add_field('senderName', "#{params[:first_name]} #{params[:last_name]}")
          end

          def fetch_token
            uri = URI.parse(PagSeguro.invoicing_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Post.new(uri.request_uri)
            request.content_type = "application/x-www-form-urlencoded"
            request.set_form_data @fields

            response = http.request(request)
            xml = Nokogiri::XML.parse(response.body)
            xml.css("code").text
          end

        end
      end
    end
  end
end
