class Hash
  def add_stringified_keys!
    keys.each {|key| self[key.to_s] = self[key] }
  end
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          # change to line_items?
          attr_reader :cart_items

          mapping :currency, 'purchase_currency'
          mapping :return_url, 'merchant_confirmation_uri'
          mapping :notify_url, 'merchant_push_uri'
          mapping :cancel_return_url, ['merchant_terms_uri', 'merchant_checkout_uri', 'merchant_base_uri', 'merchant_confirmation_uri']
          mapping :account, 'merchant_id'
          mapping :credential2, 'shared_secret'

          def initialize(order, account, options = {})
            super
            @shared_secret = @fields['shared_secret']

            # I feel like the reason I'm doing this is a bug in AM
            add_field('purchase_country', options[:country])

            add_field('platform_type', application_id)
            add_field('locale', guess_locale_based_on_country(options[:country]))

            self.cart_items = options[:cart_items]
          end

          def line_item(item)
            @line_items ||= []
            item.add_stringified_keys!
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

          def form_fields
            merchant_digest = Klarna.sign(@fields, @line_items, @shared_secret)
            add_field('merchant_digest', merchant_digest)

            add_field('test_mode', 'true') if test?

            super
          end

          def cart_items=(items)
            @cart_items = items ||= []

            items.each_with_index do |item, i|
              add_field("cart_item-#{i}_type", item.type.to_s)
              add_field("cart_item-#{i}_reference", item.reference.to_s)
              add_field("cart_item-#{i}_name", item.name.to_s)
              add_field("cart_item-#{i}_quantity", item.quantity.to_s)
              add_field("cart_item-#{i}_unit_price", item.unit_price.to_s)
              add_field("cart_item-#{i}_discount_rate", item.discount_rate.to_s) if item.respond_to?(:discount_rate)
              add_field("cart_item-#{i}_tax_rate", item.tax_rate)
            end
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
              raise StandardError, "Unable to guess locale based on country #{country_code}"
            end
          end
        end
      end
    end
  end
end
