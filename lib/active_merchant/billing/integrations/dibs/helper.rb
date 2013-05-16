module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dibs
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          
          def initialize(orderid, merchantid, options = {})
            super
            add_field("merchant", merchantid)
            add_field('test', 1) if test?
          end     
          
          def form_fields
           # You can define HMAC in your initializers
           if defined?(HMAC)
             mac = calc_mac(@fields)  
            return @fields.merge("MAC" => mac)
           end
           return @fields
          end   
          
          def calc_mac(post) 
            string = "";
            post.sort.map do |key,value|
          if key != "MAC"
            if string.length > 0 
              string += "&"
            end
              string += "#{key}=#{value}"
           end 
          end
            OpenSSL::HMAC.hexdigest('sha256', hexto_sring(HMAC), string)  
          end
      
          def hexto_sring(hex)
           string = ""
           var = hex.scan(/.{2}/)
           var.map do |value|
           string += value.hex.chr
           end
           return string
         end
          
          mapping :merchant, 'merchant'
          mapping :account, ''
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          mapping :order, 'orderid'
          mapping :acceptreturnurl, 'acceptreturnurl'
          mapping :language, 'language'
          mapping :addfee, 'addfee'
          mapping :paytype, 'paytype'
          mapping :capturenow, 'capturenow'
          mapping :billing_address, :billingfirstname    => 'billingfirstname',
                                    :billinglastname => 'billinglastname',
                                    :billingaddress => 'billingaddress',
                                    :billingaddress2   => 'billingaddress2',
                                    :billingpostalcode     => 'billingpostalcode',
                                    :billingpostalplace  => 'billingpostalplace',
                                    :billingemail=> 'billingemail',
                                    :billingmobile => 'billingmobile'
          mapping :cancelreturnurl, 'cancelreturnurl'
          mapping :callbackurl, 'callbackurl'
          mapping :oiNames, 'oinames'
          mapping :oiTypes, 'oitypes'
          mapping :test, 'test'
          
          (0..499.to_i).each do |i|
            mapping "oiRow#{i}".to_sym, "oiRow#{i}"
          end
          
        end
      end
    end
  end
end
