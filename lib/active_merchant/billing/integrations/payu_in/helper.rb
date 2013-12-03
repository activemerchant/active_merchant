module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          CHECKSUM_FIELDS = [ 'txnid', 'amount', 'productinfo', 'firstname', 'email', 'udf1', 'udf2', 'udf3', 'udf4',
                              'udf5', 'udf6', 'udf7', 'udf8', 'udf9', 'udf10']

          mapping :amount, 'amount'
          mapping :account, 'key'
          mapping :order, 'txnid'
          mapping :description, 'productinfo'

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
            @options = options
            self.pg = 'CC'
          end

          def form_fields
            sanitize_fields
            @fields.merge(mappings[:checksum] => generate_checksum)
          end

          def generate_checksum
            checksum_payload_items = CHECKSUM_FIELDS.map { |field| @fields[field] }

            PayuIn.checksum(@fields["key"], @options[:credential2], checksum_payload_items )
          end

          def sanitize_fields
            ['address1', 'address2', 'city', 'state', 'country', 'productinfo', 'email', 'phone'].each do |field|
              @fields[field].gsub!(/[^a-zA-Z0-9\-_@\/\s.]/, '') if @fields[field]
            end
          end

        end

      end
    end
  end
end
