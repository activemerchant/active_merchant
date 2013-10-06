module ActiveMerchant
  module Billing
    module Integrations
      module Citrus
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :order, 'merchantTxnId'
          mapping :amount, 'orderAmount'
          mapping :account, 'merchantAccessKey'
          mapping :credential2, 'secret_key'
          mapping :credential3, 'pmt_url'
          mapping :currency, 'currency'

          mapping :customer, :first_name => 'firstName',:last_name => 'lastName', :email => 'email', :phone => 'mobileNo'

          mapping :billing_address, :city => 'addressCity', :address1 => 'addressStreet1', :address2 => 'addressStreet2',:state => 'addressState',:zip => 'addressZip', :country => 'addressCountry'

          mapping :checksum, 'secSignature'
          mapping :return_url, 'returnUrl'


          def initialize(order, account, options = {})
            super
            add_field 'paymentMode', 'NET_BANKING'
            add_field 'reqtime', (Time.now.to_i * 1000).to_s
          end

          def form_fields
            @fields.merge(mappings[:checksum] => generate_checksum)
          end

          def generate_checksum
            checksum_fields = @fields["pmt_url"] + @fields["orderAmount"].to_s + @fields["merchantTxnId"] + @fields["currency"]
            Citrus.checksum(@fields["secret_key"],  checksum_fields )
          end
        end
      end
    end
  end
end
