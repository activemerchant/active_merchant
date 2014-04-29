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
          mapping :customer, email: 'shipping_address_email'

          def initialize(order, account, options = {})
            super
            @shared_secret = options[:credential2]

            add_field('platform_type', application_id)
            add_field('test_mode', test?)
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
            add_field("cart_item-#{i}_tax_rate", tax_rate_for(item))

            @fields
          end

          def billing_address(billing_fields)
            country = billing_fields[:country]

            add_field('purchase_country', country)
            add_field('locale', guess_locale_based_on_country(country))
          end

          def shipping_address(shipping_fields)
            add_field('shipping_address_given_name', shipping_fields[:first_name])
            add_field('shipping_address_family_name', shipping_fields[:last_name])

            street_address = [shipping_fields[:address1], shipping_fields[:address2]].compact.join(', ')
            add_field('shipping_address_street_address', street_address)

            add_field('shipping_address_postal_code', shipping_fields[:zip])
            add_field('shipping_address_city', shipping_fields[:city])
            add_field('shipping_address_country', shipping_fields[:country])
            add_field('shipping_address_phone', shipping_fields[:phone])
          end

          def form_fields
            sign_fields

            super
          end

          def sign_fields
            merchant_digest = Klarna.sign(@fields, @line_items, @shared_secret)
            add_field('merchant_digest', merchant_digest)
          end

          private

          def guess_locale_based_on_country(country_code)
            case country_code
            when /no/i
              "nb-no"
            when /fi/i
              "fi-fi"
            when /se/i
              "sv-se"
            else
              "sv-se"
            end
          end

          def tax_rate_for(item)
            subtotal_price = item.fetch(:unit_price, 0).to_f * item.fetch(:quantity, 0).to_f
            tax_amount = item.fetch(:tax_amount, 0).to_f

            tax_rate = tax_amount / subtotal_price
            tax_rate = tax_rate.round(4)

            percentage_to_two_decimal_precision_whole_number(tax_rate)
          end

          def percentage_to_two_decimal_precision_whole_number(percentage)
            (percentage * 10000).to_i
          end
        end
      end
    end
  end
end
