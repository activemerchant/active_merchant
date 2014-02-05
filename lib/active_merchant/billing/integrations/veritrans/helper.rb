module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Veritrans
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          class_attribute :item_keys 
          def initialize order, account , options = {}
            @order    = order
            @mid      = account
            @mhaskey  = options.delete(:merchant_hash_key)
            super
            @fields['SHIPPING_FLAG']               = '0'
            @fields['CUSTOMER_SPECIFICATION_FLAG'] = '0'
            add_field 'SESSION_ID',  SecureRandom.hex(13)
            self.settlement_type = '01'
          end

          def form_fields
            add_field 'MERCHANTHASH', merchanthash
            generate_token
            browser_fields = %w{MERCHANT_ID ORDER_ID TOKEN_BROWSER TOKEN_MERCHANT}
            @fields.reject{|key, value| !browser_fields.include?(key)}
          end

          def shipping_same_as_billing= _bool
            add_field 'CUSTOMER_SPECIFICATION_FLAG' , _bool == true ? 0 : 1  
          end

          def shipping_required= _bool
            @fields['SHIPPING_FLAG'] =  _bool == true ? '1' : '0'
          end
          def add_field(name, value)
            if  name.to_s.match(/^SHIPPING_/) and @fields['CUSTOMER_SPECIFICATION_FLAG'].to_i == 0
              @fields['CUSTOMER_SPECIFICATION_FLAG'] = '1' 
            end

            if @fields['CUSTOMER_SPECIFICATION_FLAG'].to_i == 1 and @fields['SHIPPING_FLAG'].to_i == 0
              @fields['SHIPPING_FLAG'] = '1'
            end

            super
          end          
          
          def items
            @items ||= Comodities.new
          end

          mapping :amount,          'GROSS_AMOUNT'
          mapping :order,           'ORDER_ID'
          mapping :account,         'MERCHANT_ID'
          mapping :return_url,      'FINISH_PAYMENT_RETURN_URL'
          mapping :cancel_url,      'UNFINISH_PAYMENT_RETURN_URL' 
          mapping :error_url,       'ERROR_PAYMENT_RETURN_URL' 
          mapping :settlement_type, 'SETTLEMENT_TYPE'
          mapping :amount,          'GROSS_AMOUNT'

          mapping :customer,  :first_name      => 'FIRST_NAME',
                              :last_name       => 'LAST_NAME',
                              :address_1       => 'ADDRESS1',
                              :address_2       => 'ADDRESS2',
                              :city            => 'CITY',
                              :country_code    => 'COUNTRY_CODE',
                              :zip             => 'POSTAL_CODE',
                              :phone           => 'PHONE',
                              :email           => 'EMAIL'

          mapping :shipping,  :first_name      => 'SHIPPING_FIRST_NAME',
                              :last_name       => 'SHIPPING_LAST_NAME',
                              :address_1       => 'SHIPPING_ADDRESS1',
                              :address_2       => 'SHIPPING_ADDRESS2',
                              :city            => 'SHIPPING_CITY',
                              :country_code    => 'SHIPPING_COUNTRY_CODE',
                              :zip             => 'SHIPPING_POSTAL_CODE',
                              :phone           => 'SHIPPING_PHONE'
       
          private

          def merchanthash
            if @merchanthash.blank?
              _settlement_type  = @fields['SETTLEMENT_TYPE']
              _amount           = @fields['GROSS_AMOUNT']
              @merchanthash = Digest::SHA512.hexdigest "#{@mhaskey},#{@mid},#{_settlement_type},#{@order},#{_amount}"
            end
            @merchanthash
          end

          def generate_token
            token = TokenRequest.new(@fields, @items).commit
            if token.errors.nil?
              add_field('TOKEN_BROWSER', token.browser)
            end
          end
        end
      end
    end
  end
end
