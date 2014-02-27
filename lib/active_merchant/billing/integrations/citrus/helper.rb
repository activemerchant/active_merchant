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

          SANDBOX_URL = 'https://sandbox.citruspay.com/'.freeze
          STAGING_URL = 'https://stg.citruspay.com/'.freeze
          PRODUCTION_URL = 'https://www.citruspay.com/'.freeze

          def credential_based_url
            pmt_url = @fields['pmt_url']
            case ActiveMerchant::Billing::Base.integration_mode
            when :production
              PRODUCTION_URL + pmt_url
            when :test
              SANDBOX_URL    + pmt_url
            when :staging
              STAGING_URL    + pmt_url
            else
              raise StandardError, "Integration mode set to an invalid value: #{mode}"
            end
          end

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
