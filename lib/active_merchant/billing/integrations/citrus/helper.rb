module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Citrus
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :amount, 'orderAmount'
          mapping :credential1, 'merchantAccessKey'
          mapping :order, 'merchantTxnId'
          

          mapping :customer, :first_name => 'firstName',
            :last_name => 'lastName',
            :email => 'email',
            :phone => 'phoneNumber'

          mapping :billing_address, :city => 'addressCity',
            :address1 => 'addressStreet1',
            :state => 'addressState',
            :zip => 'addressZip',
            :country => 'addressCountry'

          # Which tab you want to be open default on Citrus
          # CC (CreditCard) or NB (NetBanking)
          mapping :mode, 'paymentMode'

          mapping :notify_url, 'notify_url'
          mapping :return_url, ['surl', 'furl']
          mapping :cancel_return_url, 'curl'
          mapping :checksum, 'hash'
		  mapping :return_url, 'returnUrl'
		  mapping :currency, 'currency'
          
          def initialize(order, account, options = {})
            super
            self.paymentMode = 'NET_BANKING'
          end

          def form_fields
            @fields.merge(mappings[:secSignature] => generate_checksum)
          end

          def generate_checksum( options = {} )
            checksum_fields = [ :order, :amount, :credential2, { :customer => [ :first_name, :email ] },
              { :user_defined => [ :var1, :var2, :var3, :var4, :var5, :var6, :var7, :var8, :var9, :var10 ] } ]
            checksum_payload_items = checksum_fields.inject( [] ) do | items, field |
              if Hash === field then
                key = field.keys.first
                field[key].inject( items ){ |s,x| items.push( @fields[ mappings[key][x] ] ) }
              else
                items.push( @fields[ mappings[field] ] )
              end
            end
            checksum_payload_items.push( options )
            PayuIn.checksum(@fields["key"], @fields["productinfo"], *checksum_payload_items )
          end

        end

      end
    end
  end
end