module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dotpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            options = {:currency => 'PLN'}.merge options

            super

            add_field('channel', '0')
            add_field('ch_lock', '0')
            add_field('lang', 'PL')
            add_field('onlinetransfer', '0')
            add_field('tax', '0')
            add_field('type', '2')
          end

          mapping :account,         'id'
          mapping :amount,          'amount'

          mapping :billing_address, :street => 'street',
                                    :street_n1 => 'street_n1',
                                    :street_n2 => 'street_n2',
                                    :addr2 => 'addr2',
                                    :addr3 => 'addr3',
                                    :city => 'city',
                                    :postcode => 'postcode',
                                    :phone => 'phone',
                                    :country => 'country'

          mapping :buttontext,      'buttontext'
          mapping :channel,         'channel'
          mapping :ch_lock,         'ch_lock'
          mapping :code,            'code'
          mapping :control,         'control'
          mapping :currency,        'currency'

          mapping :customer,        :firstname => 'firstname',
                                    :lastname => 'lastname',
                                    :email => 'email'

          mapping :description,     'description'
          mapping :lang,            'lang'
          mapping :onlinetransfer,  'onlinetransfer'
          mapping :order,           'description'
          mapping :p_email,         'p_email'
          mapping :p_info,          'p_info'
          mapping :tax,             'tax'
          mapping :type,            'type'
          mapping :url,             'url'
          mapping :urlc,            'urlc'

          def billing_address(params = {})
            country = lookup_country_code(params.delete(:country) { 'POL' }, :alpha3)
            add_field(mappings[:billing_address][:country], country)

            # Everything else
            params.each do |k, v|
              field = mappings[:billing_address][k]
              add_field(field, v) unless field.nil?
            end
          end

          private

          def lookup_country_code(name_or_code, format = country_format)
            country = Country.find(name_or_code)
            country.code(format).to_s
          rescue InvalidCountryCodeError
            name_or_code
          end
        end
      end
    end
  end
end
