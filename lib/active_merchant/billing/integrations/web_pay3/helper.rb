module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WebPay3
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            @key = options[:credential2]
            add_field('language', options[:credential3])
            add_field('transaction_type', options[:transaction_type])
            add_field('digest', digest)
          end

          # merchant
          mapping :account, 'merchant_token'
          mapping :return_url, 'return_url'

          # order
          mapping :order, 'order_number'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          mapping :order_info, 'order_info'

          # buyer
          # :name, :company, :address1, :address2, :city, :state, :country, :zip, :phone
          def address(address_fields)
            add_field('ch_full_name', address_fields[:name])
            add_field('ch_address', address_fields[:address1])
            add_field('ch_city', address_fields[:city])
            add_field('ch_zip', address_fields[:zip])
            add_field('ch_country', address_fields[:country])
            add_field('ch_phone', address_fields[:phone])
            add_field('ch_email', address_fields[:email])
          end

          private

          # digest = SHA1(key + order_number + amount + currency)
          def digest
            Digest::SHA1.hexdigest("#{@key}#{@fields['order_number']}#{@fields['amount']}#{@fields['currency']}")
          end
        end
      end
    end
  end
end
