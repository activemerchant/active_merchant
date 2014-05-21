module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Universal
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          CURRENCY_SPECIAL_MINOR_UNITS = {
            'BIF' => 0,
            'BYR' => 0,
            'CLF' => 0,
            'CLP' => 0,
            'CVE' => 0,
            'DJF' => 0,
            'GNF' => 0,
            'HUF' => 0,
            'ISK' => 0,
            'JPY' => 0,
            'KMF' => 0,
            'KRW' => 0,
            'PYG' => 0,
            'RWF' => 0,
            'UGX' => 0,
            'UYI' => 0,
            'VND' => 0,
            'VUV' => 0,
            'XAF' => 0,
            'XOF' => 0,
            'XPF' => 0,
            'BHD' => 3,
            'IQD' => 3,
            'JOD' => 3,
            'KWD' => 3,
            'LYD' => 3,
            'OMR' => 3,
            'TND' => 3,
            'COU' => 4
          }

          def initialize(order, account, options = {})
            @forward_url = options[:forward_url]
            @key = options[:credential2]
            @currency = options[:currency]
            super
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

          def amount=(amount)
            add_field 'x_amount', format_amount(amount, @currency)
          end

          def shipping(amount)
            add_field 'x_amount_shipping', format_amount(amount, @currency)
          end

          def tax(amount)
            add_field 'x_amount_tax', format_amount(amount, @currency)
          end

          def sign_fields
            @fields.merge!('x_signature' => generate_signature)
          end

          def generate_signature
            Universal.sign(@fields, @key)
          end

          mapping :account,          'x_account_id'
          mapping :currency,         'x_currency'
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

          private

          def format_amount(amount, currency)
            units = CURRENCY_SPECIAL_MINOR_UNITS[currency] || 2
            sprintf("%.#{units}f", amount)
          end
        end
      end
    end
  end
end
