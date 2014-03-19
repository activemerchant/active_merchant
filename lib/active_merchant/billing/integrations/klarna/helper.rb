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

            # These assignments trigger the mapping-created method_missing-
            # created add_fields calls This is so much more complex than
            # necessary. Should I just do add_field calls throughout?
            self.platform_type = application_id
            self.country = options[:country]
            self.locale = guess_locale_based_on_country(options[:country])
            self.cart_items = options[:cart_items]
            self.merchant_id = account
          end

          def form_fields
            # Ninja-add merchant_uri fields if missing so signing does not blow up
            %w(merchant_terms_uri 
               merchant_checkout_uri
               merchant_base_uri
               merchant_confirmation_uri).each do |field|
              
              if !@fields.has_key?(field)
                # I feel *really* weird about not using the #add_fields API here
                # and suspect that this will later cause unexpected behaviour
                @fields[field] = ''
              end
            end

            # Ninja-add merchant_digest since it depends on
            # the above merchant URIs
            # Note how just making this assignment makes an add_field call
            self.merchant_digest = generate_merchant_digest

            add_field('test_mode', 'true') if test?

            super
          end

          def cancel_return_url(url)
            @shop_url = url
            %w(merchant_terms_uri 
               merchant_checkout_uri
               merchant_base_uri
               merchant_confirmation_uri).each do |field|
              add_field(field, url)
            end
          end

          def cart_items=(items)
            @cart_items = items ||= []

            items.each_with_index do |item, i|
              add_field("cart_item-#{i}_type", item.type.to_s)
              add_field("cart_item-#{i}_reference", item.reference.to_s)
              add_field("cart_item-#{i}_name", item.name.to_s)
              add_field("cart_item-#{i}_quantity", item.quantity.to_s)
              add_field("cart_item-#{i}_unit_price", item.unit_price.to_s)
              add_field("cart_item-#{i}_discount_rate", 0.to_s)
              add_field("cart_item-#{i}_tax_rate", item.tax_rate)
            end
          end

          private

          def generate_merchant_digest
            Klarna.sign(@fields, @cart_items, @shared_secret)
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
