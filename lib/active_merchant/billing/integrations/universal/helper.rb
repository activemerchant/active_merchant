module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Universal
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            super
            @key = options[:credential2]
            self.country = options[:country]
            self.account_name = options[:account_name]
            self.transaction_type = options[:transaction_type]
          end

          def generate_signature
            Universal.sign(@fields, @key)
          end

          def form_fields
            @fields.merge!(standard_fields)
            @fields.merge!('x-signature' => generate_signature)
          end

          def standard_fields
            fields = {}
            fields[mappings[:test]] = @test.to_s
            fields
          end

          mapping          :account, 'x-id'
          mapping         :currency, 'x-currency'
          mapping           :amount, 'x-amount'
          mapping         :shipping, 'x-amount-shipping'
          mapping              :tax, 'x-amount-tax'
          mapping            :order, 'x-reference'
          mapping          :country, 'x-shop-country'
          mapping     :account_name, 'x-shop-name'
          mapping :transaction_type, 'x-transaction-type'
          mapping      :description, 'x-description'
          mapping          :invoice, 'x-invoice'
          mapping             :test, 'x-test'

          mapping :customer, :first_name => 'x-customer-first-name',
                              :last_name => 'x-customer-last-name',
                                  :email => 'x-customer-email',
                                  :phone => 'x-customer-phone'

          mapping :billing_address,     :city => 'x-customer-city',
                                     :company => 'x-customer-company',
                                    :address1 => 'x-customer-address1',
                                    :address2 => 'x-customer-address2',
                                       :state => 'x-customer-state',
                                         :zip => 'x-customer-zip',
                                     :country => 'x-customer-country',
                                       :phone => 'x-customer-phone'

          mapping        :notify_url, 'x-url-callback'
          mapping        :return_url, 'x-url-complete'
          mapping :cancel_return_url, 'x-url-cancel'

        end
      end
    end
  end
end
