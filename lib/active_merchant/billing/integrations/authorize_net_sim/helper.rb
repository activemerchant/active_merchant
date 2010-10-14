require 'active_support/core_ext/float/rounding.rb' # Float#round(precision)

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module AuthorizeNetSim
        #  example. Note the username as a parameter, and transaction key used later
        #
        #  payment_service_for('44','8wd65QS', :service => :authorize_net_sim,  :amount => 157.0){|service|
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
        #   service.invoice "516428355"
        #   service.notify_url "http://t/authorize_net_sim/payment_received_notification_sub_step"
        #   # NB that you will need to setup, within authorize.net, what you want for your relay url, as above.
        #   # (auth.net calls back to that url, and displays its text back to the user--typically you have that text redirect them back to your site).
        #   service.payment_header 'My store name'
        #   service.add_line_item :name => 'item name', :quantity => 1, :unit_price => 0
        #   service.test_request 'true' # only if it's just a test
        #   service.shipping '25.0'
        #   service.add_shipping_as_line_item # tell it to display a "0" line item for shipping, with the price in the name
        #   server.add_tax_as_line_item # same with tax
        #   since otherwise, bizarrely, it isn't shown at all, leaving the end user to wonder why the total is different than the sum of the line items.
        #   See the helper.rb file for various custom fields
        #   }
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          
          # any entry args, like :amount, must be done using this mapping fella...
           
          mapping :order, 'x_fp_sequence'
          mapping :account, 'x_login'
          
          mapping :customer, :first_name => 'x_first_name',
                             :last_name  => 'x_last_name',
                             :email      => 'x_email',
                             :phone      => 'x_phone'
                            
          mapping :notify_url, 'x_relay_url'
          mapping :return_url, ''
          mapping :cancel_return_url, ''
          
          # custom fields for Authorize.net SIM ==>
          # see http://www.authorize.net/support/SIM_guide.pdf for more descriptions
          mapping :fax, 'x_fax'
          mapping :customer_id, 'x_cust_id'
          mapping :description, 'x_description' # This one isn't even shown to the user unless you specifically set it up to be
          # these next two ignored by AN (?)
          mapping :tax, 'x_tax'
          mapping :shipping, 'x_freight'
          
          # true or false, or 0 or 1 same effect [not required to send one, defaults to false]
          mapping :test_request, 'x_test_request'
          
          # this one is necessary for the notify url to be able to parse its information later!
          # they also pass back customer id, if that's useful
          def invoice number
            add_field 'x_invoice_num', number
          end
          
          # set the billing address.  Call like service.billing_address {:city => 'provo, :state => 'UT'}...
          def billing_address options # allow us to combine the addresses, just in case they use address2
            for setting in [:city, :state, :zip, :country, :po_num] do # I think po_num works
              add_field 'x_' + setting.to_s, options[setting]
            end
            raise 'must use address1 and address2' if options[:address]
            # allow for nil :address2
            add_field 'x_address', (options[:address1].to_s + ' ' + options[:address2].to_s).strip
          end
          
          # adds a custom field which you submit to authorize.net.  These fields are all passed back to you 
          # verbatim when it does its relay (callback) to you
          # note that if you call it twice with the same name, this function only uses keeps the second value you called
          # it with.
          
          def add_custom_field name, value
            add_field name, value
          end
          
          # displays tax as a line item, so they can see it. Otherwise it isn't displayed.
          def add_tax_as_line_item
            raise unless @fields['x_tax']
            add_line_item :name => 'Total Tax', :quantity => 1, :unit_price => @fields['x_tax'], :tax => 0, :line_title => 'Tax'
          end
          
          # displays shipping as a line item, so they can see it. Otherwise it isn't displayed.
          def add_shipping_as_line_item extra_options = {}
            raise 'must set shipping/freight before calling this' unless @fields['x_freight']
            add_line_item extra_options.merge({:name => 'Shipping and Handling Cost', :quantity => 1, :unit_price => @fields['x_freight'], :line_title => 'Shipping'})
          end
          
          # add ship_to_address in the same format as the normal address is added
          def ship_to_address options
            for setting in [:first_name, :last_name, :company, :city, :state, :zip, :country] do
              if options[setting] then
                add_field 'x_ship_to_' + setting.to_s, options[setting]
              end
            end
            raise 'must use :address1 and/or :address2' if options[:address]
            add_field 'x_ship_to_address', (options[:address1].to_s + ' ' + options[:address2].to_s).strip
          end
          
          # these untested , and control the look of the SIM payment page
          # note you can include a css header in descriptors, etc.
          mapping :color_link, 'x_color_link'
          mapping :color_text, 'x_color_text'
          mapping :logo_url, 'x_logo_url'
          mapping :background_url, 'x_background_url' # background image url for the page
          mapping :payment_header, 'x_header_html_payment_form'
          mapping :payment_footer, 'x_footer_html_payment_form'
          
          # for this to work you must have also passed in an email for the purchaser
          # NOTE there are more that could be added here--email body, etc.
          def yes_email_customer_from_authorizes_side
            add_field 'x_email_customer', 'TRUE'
          end

          # add a line item to authorize.net
          # call line add_line_item {:name => 'orange', :unit_price => 30, :tax_value => 'Y', :quantity => 3, }
          # note you can't pass in a negative unit price, and you can add an optional :line_title => 'special name' if you don't
          # want it to say 'Item 1' or what not, the default coded here.
          # NB cannot have a negative price, nor a name with "'s or $
          # NB that you can use the :line_title for the product name and then :name for description, if desired
          def add_line_item options
            raise 'needs name' unless options[:name]
            if @line_item_count == 30 # then add a note that we are not showing at least one -- AN doesn't display more than 30 or so
              description_of_last = @raw_html_fields[-1][1]
              # pull off the second to last section, which is the description
              description_of_last =~ />([^>]*)<\|>[YN]$/
              # create a new description, which can't be too big, so truncate here
              @raw_html_fields[-1][1] = description_of_last.gsub($1, $1[0..200] + ' + more unshown items after this one.')
            end
            
            name = options[:name]
            quantity = options[:quantity] || 1
            line_title = options[:line_title] || ('Item ' + (@line_item_count+1).to_s) # left most field
            unit_price = options[:unit_price] || 0 # could check if AN accepts it without a unit_price
            unit_price = unit_price.to_f.round(2)
            tax_value = options[:tax_value] || 'N' # takes Y or N or true, false, 0/1
            
            #
            # sanitization, in case they include a reserved word here, following their guidelines
            # unfortunately, they require 'raw' fields here, not CGI escaped, using their own delimiters.
            # 
            # Authorize.net ignores the second field (sanitized_short_name), anyway [though maybe it gets set internally somewhere...]
            # so..what if I just pass it CGI::escape instead, now?
            raise 'illegal char for line item <|>' if name.include? '<|>'
            raise 'illegal char for line item "' if name.include? '"' # I think we should be safe besides these. Hope so, as
            raise 'cannot pass in dollar sign' if unit_price.to_s.include? '$'
            raise 'must have positive or 0 unit price' if unit_price.to_f < 0
            # using CGI::escape causes it to look messed [spaces turn into +'s on user display]
            sanitized_short_name = name[0..30] # gotta keep it short
            name = name[0..255]            

            # note I don't [yet] have h here
            # I think these are the only ones that can mess it up
            add_raw_html_field "x_line_item", "#{line_title}<|>#{sanitized_short_name}<|>#{name}<|>#{quantity}<|>#{unit_price}<|>#{tax_value}"
            @line_item_count += 1
          end
            
          # if you call this it will e-mail to this email a copy of a receipt after
          # successful, from authorize.net
          def email_merchant_from_authorizes_side to_this_email
            add_field 'x_email_merchant', to_this_email
          end
          
          # Note.  You MUST call this at some point for it to actually work.  options must include :transaction_key and :order_timestamp
          def setup_hash options
            raise unless options[:transaction_key]
            raise unless options[:order_timestamp]
            amount = @fields['x_amount']
            raise 'odd -- number with no digits!' unless amount.to_s =~ /\d/
            data = "#{@fields['x_login']}^#{@fields['x_fp_sequence']}^#{options[:order_timestamp].to_i}^#{amount}^#{@fields['x_currency_code']}"
            hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('md5'), options[:transaction_key], data)
            add_field 'x_fp_hash', hmac
            add_field 'x_fp_timestamp', options[:order_timestamp].to_i
          end
          
          # Note that you should call #invoice and #setup_hash as well, for the response_url to work
          def initialize(order, account, options = {})
            super
            raise 'missing parameter' unless order and account and options[:amount]
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
