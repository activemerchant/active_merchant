module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            add_field('fixed', 'Y')
            
            if ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
              add_field('demo', 'Y')
            end 
          end
          
          # The 2checkout vendor account number
          mapping :account, 'sid'
          
          # he total amount to be billed, in decimal form, without a currency symbol. (8 characters, decimal, 2 characters: Example: 99999999.99)
          mapping :amount, 'total'
        
          # a unique order id from your program. (128 characters max)
          mapping :order, 'cart_order_id'

          mapping :mode, 'mode'

          mapping :customer, :email      => 'email',
                             :phone      => 'phone'

          mapping :billing_address, :city     => 'city',
                                    :address1 => 'street_address',
                                    :address2 => 'street_address2',
                                    :state    => 'state',
                                    :zip      => 'zip',
                                    :country  => 'country'
          
          mapping :shipping_address, :city     => 'ship_city',
                                     :address1 => 'ship_street_address',
                                     :state    => 'ship_state',
                                     :zip      => 'ship_zip',
                                     :country  => 'ship_country'
          
          mapping :invoice, 'merchant_order_id'
          
          # Does nothing, since we've disabled the Continue Shopping button by using the fixed = Y field
          mapping :return_url, 'return_url'
          
          #mapping :description, ''
          #mapping :tax, ''
          #mapping :shipping, ''
          
          def customer(params = {})
            add_field(mappings[:customer][:email], params[:email])
            add_field(mappings[:customer][:phone], params[:phone])
            add_field('card_holder_name', "#{params[:first_name]} #{params[:last_name]}")
          end
          
          def line_item(params = {})
            max_existing_line_item_id = form_fields.keys.map do |key| 
              match = key.to_s.match(/li_(\d+)_/)
              if match
                match[1]
              end
            end.reject(&:nil?).max.to_i
            
            line_item_id = max_existing_line_item_id + 1
            params.each do |key, value|
              add_field("li_#{line_item_id}_#{key}", value)
            end
          end
        end
      end
    end
  end
end
