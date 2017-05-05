module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Universal
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            super
            @forward_url = options[:forward_url]
            @key = options[:credential2]
            self.country = options[:country]
            self.account_name = options[:account_name]
            self.transaction_type = options[:transaction_type]
            add_field 'x_test', @test.to_s
          end

          def credential_based_url
            @forward_url
          end

          def form_fields
            sign_fields
          end

          def sign_fields
            @fields.merge!('x_signature' => generate_signature)
          end

          def generate_signature
            Universal.sign(@fields, @key)
          end

          mapping :account,          'x_account_id'
          mapping :currency,         'x_currency'
          mapping :amount,           'x_amount'
          mapping :shipping,         'x_amount_shipping'
          mapping :tax,              'x_amount_tax'
          mapping :order,            'x_reference'
          mapping :country,          'x_shop_country'
          mapping :account_name,     'x_shop_name'
          mapping :transaction_type, 'x_transaction_type'
          mapping :description,      'x_description'
          mapping :invoice,          'x_invoice'

          mapping :customer, :first_name => 'x_customer_first_name',
                             :last_name  => 'x_customer_last_name',
                             :email      => 'x_customer_email',
                             :phone      => 'x_customer_phone'

          mapping :billing_address, :city =>     'x_customer_billing_city',
                                    :company =>  'x_customer_billing_company',
                                    :address1 => 'x_customer_billing_address1',
                                    :address2 => 'x_customer_billing_address2',
                                    :state =>    'x_customer_billing_state',
                                    :zip =>      'x_customer_billing_zip',
                                    :country =>  'x_customer_billing_country',
                                    :phone =>    'x_customer_billing_phone'

          mapping :shipping_address, :first_name => 'x_customer_shipping_first_name',
                                     :last_name =>  'x_customer_shipping_last_name',
                                     :city =>       'x_customer_shipping_city',
                                     :company =>    'x_customer_shipping_company',
                                     :address1 =>   'x_customer_shipping_address1',
                                     :address2 =>   'x_customer_shipping_address2',
                                     :state =>      'x_customer_shipping_state',
                                     :zip =>        'x_customer_shipping_zip',
                                     :country =>    'x_customer_shipping_country',
                                     :phone =>      'x_customer_shipping_phone'

          mapping        :notify_url, 'x_url_callback'
          mapping        :return_url, 'x_url_complete'
          mapping :cancel_return_url, 'x_url_cancel'
        end
      end
    end
  end
end
