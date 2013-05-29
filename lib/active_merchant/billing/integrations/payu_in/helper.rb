module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :amount, 'amount'
          mapping :account, 'key'
          mapping :order, 'txnid'
          mapping :credential2, 'productinfo'

          mapping :customer, :first_name => 'firstname',
            :last_name  => 'lastname',
            :email => 'email',
            :phone => 'phone'

          mapping :billing_address, :city => 'city',
            :address1 => 'address1',
            :address2 => 'address2',
            :state => 'state',
            :zip => 'zip',
            :country => 'country'

          # Which tab you want to be open default on PayU
          # CC (CreditCard) or NB (NetBanking)
          mapping :mode, 'pg'

          mapping :notify_url, 'notify_url'
          mapping :return_url, ['surl', 'furl']
          mapping :cancel_return_url, 'curl'
          mapping :checksum, 'hash'

          mapping :user_defined, { :var1 => 'udf1',
            :var2 => 'udf2',
            :var3 => 'udf3',
            :var4 => 'udf4',
            :var5 => 'udf5',
            :var6 => 'udf6',
            :var7 => 'udf7',
            :var8 => 'udf8',
            :var9 => 'udf9',
            :var10 => 'udf10'
          }

          def initialize(order, account, options = {})
            super
            self.pg = 'CC'
          end

          def form_fields
            @fields.merge(mappings[:checksum] => generate_checksum)
          end

          def generate_checksum(  options = {} )
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
