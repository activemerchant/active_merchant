module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          mapping :country, 'purchase_country'
          mapping :currency, 'purchase_currency'
          mapping :return_url, 'merchant_confirmation_uri'
          mapping :notify_url, 'merchant_push_uri'

          # Add these until we have proper cart/line item support from Shopify
          mapping :order, 'cart_item-1_reference'
          mapping :invoice, 'cart_item-1_name'
          mapping :amount, 'cart_item-1_unit_price'

          %w(locale platform_type merchant_digest merchant_id).each do |field|
            mapping field.to_sym, field
          end

          def initialize(order, account, options = {})
            super
            @shared_secret = options[:credential2]
            @line_items = options[:line_items]

            self.country = options[:country]
            self.locale = guess_locale_based_on_country(options[:country])
            self.merchant_digest = generate_merchant_digest
            self.merchant_id = account

            self.platform_type = 'a57b5192-7080-443c-9867-c5346b649dc0'
            STDERR.puts "Need to confirm actual platform_type value"
          end

          def cancel_return_url(url)
            %w(merchant_terms_uri merchant_checkout_uri merchant_base_uri merchant_base_uri merchant_confirmation_uri).each do |field|
              add_field(field, url)
            end
          end

          private

          def generate_merchant_digest
            # Workaround for not having easy access to cart line items
            cart_items = [{'type' => 'physical',
                           'reference' => order,
                           'quantity' => 1,
                           'unit_price' => amount,
                           'tax_rate' => 0}]
            Klarna.sign(@fields, cart_items, @shared_secret)
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
