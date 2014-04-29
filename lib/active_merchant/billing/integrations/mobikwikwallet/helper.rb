module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Mobikwikwallet
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            @key = options[:credential2]
          end

          mapping :amount, 'amount'
          mapping :account, 'mid'
          mapping :credential3, 'merchantname'
          
          mapping :order, 'orderid'

          mapping :customer, :email      => 'email',
                             :phone      => 'cell'

          mapping :return_url, 'redirecturl'

          mapping :checksum, 'checksum'

          def form_fields
            @fields.merge(mappings[:checksum] => generate_checksum)
          end

          def generate_checksum
            checksum_fields = "'" + @fields["cell"] + "''" + @fields["email"] + "''" + @fields["amount"].to_s + "''" + @fields["orderid"] + "''" + @fields["redirecturl"] + "''" + @fields["mid"] + "'"
            Mobikwikwallet.checksum(@key,  checksum_fields)
          end

        end
      end
    end
  end
end
