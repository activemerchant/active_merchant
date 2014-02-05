require 'active_support/version' # for ActiveSupport2.3
require 'active_support/core_ext/float/rounding.rb' unless ActiveSupport::VERSION::MAJOR > 3 # Float#round(precision)

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module AuthorizeNetSim
        # An example. Note the username as a parameter and transaction key you
        # will want to use later. The amount that you pass in will be *rounded*,
        # so preferably pass in X.2 decimal so that no rounding occurs. It is
        # rounded because if it looks like 00.000 Authorize.Net fails the
        # transaction as incorrectly formatted.
        #
        #  payment_service_for('order_id', 'authorize_net_account', :service => :authorize_net_sim,  :amount => 157.0) do |service|
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
        #   # The end-user is presented with the HTML produced by the notify_url.
        #   service.notify_url "http://t/authorize_net_sim/payment_received_notification_sub_step"
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

        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :order, 'x_fp_sequence'
          mapping :account, 'x_login'

          mapping :customer, :first_name => 'x_first_name',
                             :last_name  => 'x_last_name',
                             :email      => 'x_email',
                             :phone      => 'x_phone'

          mapping :notify_url, 'x_relay_url'
          mapping :return_url, '' # unused
          mapping :cancel_return_url, '' # unused

          # Custom fields for Authorize.net SIM.
          # See http://www.Authorize.Net/support/SIM_guide.pdf for more descriptions.
          mapping :fax, 'x_fax'
          mapping :customer_id, 'x_cust_id'
          mapping :description, 'x_description'
          mapping :tax, 'x_tax'
          mapping :shipping, 'x_freight'

          # True or false, or 0 or 1 same effect [not required to send one,
          # defaults to false].
          mapping :test_request, 'x_test_request'

          # This one is necessary for the notify url to be able to parse its
          # information later! They also pass back customer id, if that's
          # useful.
          def invoice(number)
            add_field 'x_invoice_num', number
          end

          # Set the billing address. Call like service.billing_address {:city =>
          # 'provo, :state => 'UT'}...
          def billing_address(options)
            for setting in [:city, :state, :zip, :country, :po_num] do
              add_field 'x_' + setting.to_s, options[setting]
            end
            raise 'must use address1 and address2' if options[:address]
            add_field 'x_address', (options[:address1].to_s + ' ' + options[:address2].to_s).strip
          end

          # Adds a custom field which you submit to Authorize.Net. These fields
          # are all passed back to you verbatim when it does its relay
          # (callback) to you note that if you call it twice with the same name,
          # this function only uses keeps the second value you called it with.
          def add_custom_field(name, value)
            add_field name, value
          end

          # Displays tax as a line item, so they can see it. Otherwise it isn't
          # displayed.
          def add_tax_as_line_item
            raise unless @fields['x_tax']
            add_line_item :name => 'Total Tax', :quantity => 1, :unit_price => @fields['x_tax'], :tax => 0, :line_title => 'Tax'
          end

          # Displays shipping as a line item, so they can see it. Otherwise it
          # isn't displayed.
          def add_shipping_as_line_item(extra_options = {})
            raise 'must set shipping/freight before calling this' unless @fields['x_freight']
            add_line_item extra_options.merge({:name => 'Shipping and Handling Cost', :quantity => 1, :unit_price => @fields['x_freight'], :line_title => 'Shipping'})
          end

          # Add ship_to_address in the same format as the normal address is
          # added.
          def ship_to_address(options)
            for setting in [:first_name, :last_name, :company, :city, :state, :zip, :country] do
              if options[setting] then
                add_field 'x_ship_to_' + setting.to_s, options[setting]
              end
            end
            raise 'must use :address1 and/or :address2' if options[:address]
            add_field 'x_ship_to_address', (options[:address1].to_s + ' ' + options[:address2].to_s).strip
          end

          # These control the look of the SIM payment page. Note that you can
          # include a CSS header in descriptors, etc.
          mapping :color_link, 'x_color_link'
          mapping :color_text, 'x_color_text'
          mapping :logo_url, 'x_logo_url'
          mapping :background_url, 'x_background_url' # background image url for the page
          mapping :payment_header, 'x_header_html_payment_form'
          mapping :payment_footer, 'x_footer_html_payment_form'

          # For this to work you must have also passed in an email for the
          # purchaser.
          def yes_email_customer_from_authorizes_side
            add_field 'x_email_customer', 'TRUE'
          end

          # Add a line item to Authorize.Net.
          # Call line add_line_item {:name => 'orange', :unit_price => 30, :tax_value => 'Y', :quantity => 3, }
          # Note you can't pass in a negative unit price, and you can add an
          # optional :line_title => 'special name' if you don't want it to say
          # 'Item 1' or what not, the default coded here.
          # Cannot have a negative price, nor a name with "'s or $
          # You can use the :line_title for the product name and then :name for description, if desired
          def add_line_item(options)
            raise 'needs name' unless options[:name]

            if @line_item_count == 30
              # Add a note that we are not showing at least one -- AN doesn't
              # display more than 30 or so.
              description_of_last = @raw_html_fields[-1][1]
              # Pull off the second to last section, which is the description.
              description_of_last =~ />([^>]*)<\|>[YN]$/
              # Create a new description, which can't be too big, so truncate here.
              @raw_html_fields[-1][1] = description_of_last.gsub($1, $1[0..200] + ' + more unshown items after this one.')
            end

            name = options[:name]
            quantity = options[:quantity] || 1
            line_title = options[:line_title] || ('Item ' + (@line_item_count + 1).to_s) # left most field
            unit_price = options[:unit_price] || 0
            unit_price = unit_price.to_f.round(2)
            tax_value = options[:tax_value] || 'N'

            # Sanitization, in case they include a reserved word here, following
            # their guidelines; unfortunately, they require 'raw' fields here,
            # not CGI escaped, using their own delimiters.
            #
            # Authorize.net ignores the second field (sanitized_short_name)
            raise 'illegal char for line item <|>' if name.include? '<|>'
            raise 'illegal char for line item "' if name.include? '"'
            raise 'cannot pass in dollar sign' if unit_price.to_s.include? '$'
            raise 'must have positive or 0 unit price' if unit_price.to_f < 0
            # Using CGI::escape causes the output to be formated incorrectly in
            # the HTML presented to the end-user's browser (e.g., spaces turn
            # into +'s).
            sanitized_short_name = name[0..30]
            name = name[0..255]

            add_raw_html_field "x_line_item", "#{line_title}<|>#{sanitized_short_name}<|>#{name}<|>#{quantity}<|>#{unit_price}<|>#{tax_value}"

            @line_item_count += 1
          end

          # If you call this it will e-mail to this address a copy of a receipt
          # after successful, from Authorize.Net.
          def email_merchant_from_authorizes_side(to_this_email)
            add_field 'x_email_merchant', to_this_email
          end

          # You MUST call this at some point for it to actually work. Options
          # must include :transaction_key and :order_timestamp
          def setup_hash(options)
            raise unless options[:transaction_key]
            raise unless options[:order_timestamp]
            amount = @fields['x_amount']
            data = "#{@fields['x_login']}^#{@fields['x_fp_sequence']}^#{options[:order_timestamp].to_i}^#{amount}^#{@fields['x_currency_code']}"
            hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('md5'), options[:transaction_key], data)
            add_field 'x_fp_hash', hmac
            add_field 'x_fp_timestamp', options[:order_timestamp].to_i
          end

          # Note that you should call #invoice and #setup_hash as well, for the
          # response_url to actually work.
          def initialize(order, account, options = {})
            super
            raise 'missing parameter' unless order and account and options[:amount]
            raise 'error -- amount with no digits!' unless options[:amount].to_s =~ /\d/
            add_field('x_type', 'AUTH_CAPTURE') # the only one we deal with, for now.  Not refunds or anything else, currently.
            add_field 'x_show_form', 'PAYMENT_FORM'
            add_field 'x_relay_response', 'TRUE'
            add_field 'x_duplicate_window', '28800' # large default duplicate window.
            add_field 'x_currency_code', currency_code
          	add_field 'x_version' , '3.1' # version from doc
            add_field 'x_amount', options[:amount].to_f.round(2)
          	@line_item_count = 0
          end

        end
      end
    end
  end
end
