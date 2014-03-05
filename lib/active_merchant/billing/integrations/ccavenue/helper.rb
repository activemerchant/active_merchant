module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ccavenue
        class Helper < ActiveMerchant::Billing::Integrations::Helper
			include RequiresParameters
			attr_reader   :merchant_id,:workingKey
		 	mapping :amount, 'Amount'
			mapping :order, 'Order_Id'
			mapping :Checksum,'Checksum'
			mapping :redirect_url,'Redirect_Url'				
			mapping :order,'Merchant_Param'

			mapping :customer, 
			:name  => 'billing_cust_name',
			:email => 'billing_cust_email',
			:phone => 'billing_cust_tel',
			:name  => 'delivery_cust_name',
			:phone => 'delivery_cust_tel'
										 
			mapping :billing_address,
			:city     => 'billing_cust_city',
			:address1 => 'billing_cust_address',
			:state    => 'billing_cust_state',
			:zip      => 'billing_zip_code',
			:country  => 'billing_cust_country',
			:note     => 'billing_cust_notes'

			mapping :shipping_address,  
			:address1 => 'delivery_cust_address',
			:city     => 'delivery_cust_city',
			:state    => 'delivery_cust_state',
			:zip      => 'delivery_zip_code',
			:country  => 'delivery_cust_country'

			
			def initialize(order_id, account,  options = {}) 
				requires!(options, :workingKey, :amount, :currency)
				@options = options
				@merchant_id = account  
				
			end
		  
			def redirect(mapping = {}) 
				add_field( 'Redirect_Url', mapping[:redirect_url])
				add_field('Checksum', getchecksum(@merchant_id,@options[:amount],order_id,mapping[:return_url],@options[:workingKey]))
				add_field('Merchant_Id', @merchant_id) 
			end
			private

			def getchecksum(*args)
				require 'zlib'
				Zlib.adler32 args.join('|'), 1
			end	 	
          end
		end
      end
    end
  end
