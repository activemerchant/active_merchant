module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :account, 'pay_to_email'
          mapping :order, 'transaction_id'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          
          mapping :customer,
            :first_name => 'firstname',
            :last_name  => 'lastname',
            :email      => 'pay_from_email',
            :phone      => 'phone_number'

          mapping :billing_address,
            :city     => 'city',
            :address1 => 'address',
            :address2 => 'address2',
            :state    => 'state',
            :zip      => 'postal_code',
            :country  => 'country'

          mapping :notify_url, 'status_url'
          mapping :return_url, 'return_url'
          mapping :cancel_return_url, 'cancel_url'
          mapping :description, 'detail1_text'

          MAPPED_COUNTRY_CODES = {
            'SE' => 'SV', 
            'DK' => 'DA'
          }

          SUPPORTED_COUNTRY_CODES = [
            'FI', 'DE', 'ES', 'FR', 
            'IT','PL', 'GR', 'RO', 
            'RU', 'TR', 'CN', 'CZ', 'NL'
          ]
          
          def initialize(order, account, options = {})
            super
            add_tracking_token
            add_default_parameters
            add_seller_details(options)
          end

          private
          
          def add_tracking_token
            return if application_id.blank? || application_id == 'ActiveMerchant'

            add_field('merchant_fields', 'platform')
            add_field('platform', application_id)
          end
          
          def add_default_parameters
            add_field('hide_login', 1)
          end
          
          def add_seller_details(options)
            add_field('recipient_description', options[:account_name]) if options[:account_name]
            add_field('country', lookup_country_code(options[:country], :alpha3)) if options[:country]
            add_field('language', locale_code(options[:country])) if options[:country]
          end

          def locale_code(country_code)
            return country_code if SUPPORTED_COUNTRY_CODES.include?(country_code)
            MAPPED_COUNTRY_CODES[country_code] || 'EN'
          end
        end
      end
    end
  end
end
