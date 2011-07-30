module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayflowLink
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            super
            add_field('login', account)
            add_field('type', 'S')
            add_field('echodata', 'True')
            add_field('user2', ActiveMerchant::Billing::Base.integration_mode == :test || options[:test])
            add_field('invoice', order)
          end

          mapping :amount, 'amount'
          mapping :account, 'login'
          mapping :credential2, 'partner'
          mapping :order, 'user1'
          mapping :description, 'description'


          mapping :billing_address,  :city    => 'city',
                                     :address => 'address',
                                     :state   => 'state',
                                     :zip     => 'zip',
                                     :country => 'country',
                                     :phone   => 'phone',
                                     :name    => 'name'

          mapping :customer, :name => 'name'

          def customer(params = {})
            add_field(mappings[:customer][:name], [params.delete(:first_name), params.delete(:last_name)].compact.join(' '))
          end

          def billing_address(params = {})
            # Get the country code in the correct format
            # Use what we were given if we can't find anything
            country_code = lookup_country_code(params.delete(:country))
            add_field(mappings[:billing_address][:country], country_code)

            add_field(mappings[:billing_address][:address], [params.delete(:address1), params.delete(:address2)].compact.join(' '))

            province_code = params.delete(:state)
            add_field(mappings[:billing_address][:state], province_code.blank? ? 'N/A' : province_code.upcase)

            # Everything else
            params.each do |k, v|
              field = mappings[:billing_address][k]
              add_field(field, v) unless field.nil?
            end
          end
        end
      end
    end
  end
end
