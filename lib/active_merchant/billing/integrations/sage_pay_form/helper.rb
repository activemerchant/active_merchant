require 'uri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module SagePayForm
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Encryption
          
          mapping :credential2, 'EncryptKey'
          
          mapping :account, 'Vendor'
          mapping :amount, 'Amount'
          mapping :currency, 'Currency'
        
          mapping :order, 'VendorTxCode'

          mapping :customer,
            :first_name => 'BillingFirstnames',
            :last_name  => 'BillingSurname',
            :email      => 'CustomerEMail',
            :phone      => 'BillingPhone',
            :send_email_confirmation => 'SendEmail'

          mapping :billing_address,
            :city     => 'BillingCity',
            :address1 => 'BillingAddress1',
            :address2 => 'BillingAddress2',
            :state    => 'BillingState',
            :zip      => 'BillingPostCode',
            :country  => 'BillingCountry'

          mapping :shipping_address,
            :city     => 'DeliveryCity',
            :address1 => 'DeliveryAddress1',
            :address2 => 'DeliveryAddress2',
            :state    => 'DeliveryState',
            :zip      => 'DeliveryPostCode',
            :country  => 'DeliveryCountry'

          mapping :return_url, 'SuccessURL'
          mapping :description, 'Description'

          def form_fields
            fields['DeliveryFirstnames'] ||= fields['BillingFirstnames']
            fields['DeliverySurname']    ||= fields['BillingSurname']
            
            fields['FailureURL'] ||= fields['SuccessURL']

            crypt_skip = ['Vendor', 'EncryptKey', 'SendEmail']
            crypt_skip << 'BillingState'  unless fields['BillingCountry']  == 'US'
            crypt_skip << 'DeliveryState' unless fields['DeliveryCountry'] == 'US'
            crypt_skip << 'CustomerEMail' unless fields['SendEmail']
            
            key = fields['EncryptKey']
            @crypt ||= create_crypt_field(fields.except(*crypt_skip), key)
            
            {
              'VPSProtocol' => '2.23',
              'TxType' => 'PAYMENT',
              'Vendor' => @fields['Vendor'],
              'Crypt'  => @crypt
            }
          end

          private

          def create_crypt_field(fields, key)
            parts = fields.map { |k, v| "#{k}=#{sanitize(k, v)}" unless v.nil? }.compact.shuffle
            parts.unshift(sage_encrypt_salt(key.length, key.length * 2))
            sage_encrypt(parts.join('&'), key)
          end

          def sanitize(key, value)
            reject = exact = nil
            
            case key
            when /URL$/
              # allow all
            when 'VendorTxCode'
              reject = /[^A-Za-z0-9{}._-]+/
            when /[Nn]ames?$/
              reject = %r{[^[:alpha:] /\\.'-]+}
            when /(?:Address[12]|City)$/
              reject = %r{[^[:alnum:] +'/\\:,.\n()-]+}
            when /PostCode$/
              reject = /[^A-Za-z0-9 -]+/
            when /Phone$/
              reject = /[^0-9A-Za-z+ ()-]+/
            when 'Currency'
              exact = /^[A-Z]{3}$/
            when /State$/
              exact = /^[A-Z]{2}$/
            else
              reject = /&+/
            end
            
            if exact
              raise ArgumentError, "Invalid value for #{key}: #{value.inspect}" unless value =~ exact
              value
            elsif reject
              value.gsub(reject, ' ')
            else
              value
            end
          end
        end
      end
    end
  end
end
