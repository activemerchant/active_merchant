module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          attr_reader :cart_items

          mapping :country, 'purchase_country'
          mapping :currency, 'purchase_currency'
          mapping :return_url, 'merchant_confirmation_uri'
          mapping :notify_url, 'merchant_push_uri'

          %w(locale platform_type merchant_digest merchant_id).each do |field|
            mapping field.to_sym, field
          end

          def initialize(order, account, options = {})
            super
            @shared_secret = options[:credential2]

            self.platform_type = application_id
            self.country = options[:country]
            self.locale = guess_locale_based_on_country(options[:country])
            self.cart_items = options[:cart_items]
            self.merchant_id = account

            self.merchant_digest = generate_merchant_digest
          end

          def cancel_return_url(url)
            %w(merchant_terms_uri merchant_checkout_uri merchant_base_uri merchant_base_uri merchant_confirmation_uri).each do |field|
              add_field(field, url)
            end
          end

          def cart_items=(items)
            @cart_items = items ||= []

            items.each_with_index do |item, i|
              add_field("cart_item-#{i+1}_type", item.type.to_s)
              add_field("cart_item-#{i+1}_reference", item.reference.to_s)
              add_field("cart_item-#{i+1}_name", item.name.to_s)
              add_field("cart_item-#{i+1}_quantity", item.quantity.to_s)
              add_field("cart_item-#{i+1}_unit_price", item.unit_price.to_s)
              add_field("cart_item-#{i+1}_tax_rate", item.tax_rate.to_s)
            end
          end

          private

          def generate_merchant_digest            
            Klarna.sign(@fields, @cart_items, @shared_secret)
          end

          def guess_locale_based_on_country(country_code)
            case country_code
            when /no/i
              "Nb No"
            when /fi/i
              "Fi Fi"
            when /se/i
              "Sv Se"
            else
              raise StandardError, "Unable to guess locale based on country #{country_code}"
            end
          end
        end
      end
    end
  end
end
