module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module FirstData
        # First Data payment pages emulates the Authorize.Net SIM API. See
        # ActiveMerchant::Billing::Integrations::AuthorizeNetSim::Helper for
        # more details.
        #
        # An example. Note the username as a parameter and transaction key you
        # will want to use later.
        #
        #  payment_service_for('order_id', 'first_data_payment_page_id', :service => :first_data,  :amount => 157.0) do |service|
        #
        #    # You must call setup_hash and invoice
        #
        #    service.setup_hash :transaction_key => '8CP6zJ7uD875J6tY',
        #        :order_timestamp => 1206836763
        #    service.customer_id 8
        #    service.customer :first_name => 'g',
        #                       :last_name => 'g',
        #                       :email => 'g@g.com',
        #                       :phone => '3'
        #   service.billing_address :zip => 'g',
        #                   :country => 'United States of America',
        #                   :address => 'g'
        #
        #   service.ship_to_address :first_name => 'g',
        #                            :last_name => 'g',
        #                            :city => '',
        #                            :address => 'g',
        #                            :address2 => '',
        #                            :state => address.state,
        #                            :country => 'United States of America',
        #                            :zip => 'g'
        #
        #   service.invoice "516428355" # your invoice number
        #   # The end-user is presented with the HTML produced by the notify_url
        #   # (using the First Data Receipt Link feature).
        #   service.return_url "http://mysite/first_data_receipt_generator_page"
        #   service.payment_header 'My store name'
        #   service.add_line_item :name => 'item name', :quantity => 1, :unit_price => 0
        #   service.test_request 'true' # only if it's just a test
        #   service.shipping '25.0'
        #   # Tell it to display a "0" line item for shipping, with the price in
        #   # the name, otherwise it isn't shown at all, leaving the end user to
        #   # wonder why the total is different than the sum of the line items.
        #   service.add_shipping_as_line_item
        #   server.add_tax_as_line_item # same with tax
        #   # See the helper.rb file for various custom fields
        # end
        class Helper < ActiveMerchant::Billing::Integrations::AuthorizeNetSim::Helper
          # Configure notify_url to use the "Relay Response" feature
          mapping :notify_url, 'x_relay_url'

          # Configure return_url to use the "Receipt Link" feature
          mapping :return_url, 'x_receipt_link_url'
        end
      end
    end
  end
end
