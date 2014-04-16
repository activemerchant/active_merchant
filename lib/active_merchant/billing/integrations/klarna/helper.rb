module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :currency, 'purchase_currency'
          mapping :return_url, 'merchant_confirmation_uri'
          mapping :notify_url, 'merchant_push_uri'
          mapping :cancel_return_url, ['merchant_terms_uri', 'merchant_checkout_uri', 'merchant_base_uri']
          mapping :account, 'merchant_id'

          def initialize(order, account, options = {})
            super
            @shared_secret = options[:credential2]

            # I feel like the reason I'm doing this is a bug in AM
            add_field('purchase_country', options[:country])

            add_field('platform_type', application_id)
            add_field('locale', guess_locale_based_on_country(options[:country]))
          end

          def line_item(item)
            @line_items ||= []
            @line_items << item

            i = @line_items.size - 1

            add_field("cart_item-#{i}_type", item.fetch(:type, ''))
            add_field("cart_item-#{i}_reference", item.fetch(:reference, ''))
            add_field("cart_item-#{i}_name", item.fetch(:name, ''))
            add_field("cart_item-#{i}_quantity", item.fetch(:quantity, ''))
            add_field("cart_item-#{i}_unit_price", item.fetch(:unit_price, ''))
            add_field("cart_item-#{i}_discount_rate", item.fetch(:discount_rate, ''))
            add_field("cart_item-#{i}_tax_rate", item.fetch(:tax_rate, ''))

            @fields
          end

          def shipping_address(shipping_fields)
            add_field('shipping_address_given_name', shipping_fields[:first_name])
            add_field('shipping_address_family_name', shipping_fields[:last_name])

            street_address = [shipping_fields[:address1], shipping_fields[:address2]].join(', ')
            add_field('shipping_address_street_address', street_address)

            add_field('shipping_address_postal_code', shipping_fields[:zip])
            add_field('shipping_address_city', shipping_fields[:city])
            add_field('shipping_address_country', shipping_fields[:country])
            add_field('shipping_address_phone', shipping_fields[:phone])
          end

          def form_fields
            merchant_digest = Klarna.sign(@fields, @line_items, @shared_secret)
            add_field('merchant_digest', merchant_digest)

            add_field('test_mode', 'true') if test?

            add_field('shipping_address_street_address', street_address)

            super
          end

          private

          def street_address
            [address1, address2].compact.join(', ')
          end

          def guess_locale_based_on_country(country_code)
            case country_code
            when /no/i
              "nb-no"
            when /fi/i
              "fi-fi"
            when /se/i
              "sv-se"
            else
              raise StandardError, "Unable to guess locale based on country #{country_code}"
            end
          end
        end
      end
    end
  end
end
