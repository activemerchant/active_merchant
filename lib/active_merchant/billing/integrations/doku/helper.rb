module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Doku

        # # Example.
        #
        #  payment_service_for('ORDER_ID', 'DOKU_STORE_ID', :service => :doku,  :amount => 155_000, :shared_key => 'DOKU_SHARED_KEY') do |service|
        #
        #    service.add_item :name => 'Item 1',    :price => 70_000,   :quantity => 2
        #    service.add_item :name => 'Item 2',    :price => 25_000,   :quantity => 1
        #    service.add_item :name => 'Discount',  :price => -10_000,  :quantity => 1
        #
        #    service.customer :name              => 'Ismail Danuarta',
        #                     :email             => 'ismail.danuarta@gmail.com',
        #                     :mobile_phone      => '085779280093',
        #                     :working_phone     => '0215150555',
        #                     :home_phone        => '0215150555',
        #                     :birth_date        => '1991-09-11'
        #
        #    service.billing_address :city     => 'Jakarta Selatan',
        #                            :address  => 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3',
        #                            :state    => 'DKI Jakarta',
        #                            :zip      => '12190',
        #                            :country  => 'ID'

        #    service.shipping_address :city     => 'Jakarta',
        #                             :address  => 'Jl. Jendral Sudirman kav 59, Plaza Asia Office Park Unit 3',
        #                             :state    => 'DKI Jakarta',
        #                             :zip      => '12190',
        #                             :country  => 'ID'
        #
        #    service.url 'http://yourstore.com'
        #
        # end
        #

        class Helper < ActiveMerchant::Billing::Integrations::Helper
          ITEM_FORMAT = "%{name},%{price},%{quantity},%{sub_total}".freeze

          def initialize(order, account, options = {})
            @shared_key      = options.delete(:credential2)
            @transidmerchant = order
            @items           = []
            super
            self.amount      = money_format(options[:amount])
            add_field 'TRANSIDMERCHANT', order
          end

          def form_fields
            add_field 'WORDS', words
            add_field 'BASKET', basket
            @fields
          end

          def add_item(item={})
            @items << item
          end

          mapping :account,           'STOREID'
          mapping :amount,            'AMOUNT'
          mapping :cancel_return_url, 'URL'


          mapping :customer, :last_name         => 'CNAME',
                             :email             => 'CEMAIL',
                             :phone             => 'CHPHONE',
                             :mobile_phone      => 'CMPHONE',
                             :working_phone     => 'CWPHONE',
                             :birth_date        => 'BIRTHDATE'

          mapping :billing_address, :city     => 'CCITY',
                                    :address1 => 'CADDRESS',
                                    :state    => 'CSTATE',
                                    :zip      => 'CZIPCODE',
                                    :country  => 'CCOUNTRY'

          mapping :shipping_address,  :city     => 'SCITY',
                                      :address1 => 'SADDRESS',
                                      :state    => 'SSTATE',
                                      :zip      => 'SZIPCODE',
                                      :country  => 'SCOUNTRY'

          private

          def basket
            @items.map do |item|
              ITEM_FORMAT % {
                name: item[:name],
                price: money_format(item[:price]),
                quantity: item[:quantity],
                sub_total: money_format(item[:price] * item[:quantity])
              }
            end.join(';')
          end

          def words
            @words ||= Digest::SHA1.hexdigest("#{ @fields['AMOUNT'] }#{ @shared_key }#{ @transidmerchant }")
          end

          def money_format(money)
            '%.2f' % money.to_f
          end

          def add_address(key, params)
            return if mappings[key].nil?

            code = lookup_country_code(params.delete(:country), :numeric)
            add_field(mappings[key][:country], code)
            add_fields(key, params)
          end

        end
      end
    end
  end
end
