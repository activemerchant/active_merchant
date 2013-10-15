module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Netgiro
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include RequiresParameters

          SUPPORTED_CURRENCIES = %w[ISK]

          mapping :account, 'ApplicationID'
          mapping :order, 'OrderId'
          mapping :return_url, 'PaymentSuccessfulURL'
          mapping :cancel_return_url, 'PaymentCancelledURL'

          def initialize(order, account, options={})
            super
            add_field 'Iframe', 'false'
            @line_item_count = 0
            @secret = options[:credential2]
          end

          def currency(symbol)
            raise ArgumentError, "Unsupported currency" unless SUPPORTED_CURRENCIES.include?(symbol)
            # add_field mappings[:currency], symbol
          end

          def signature
            raise ArgumentError, "Secret key is not set" unless @secret
            parts = [@secret, @fields['OrderId'], amount, @fields['ApplicationID']]
            puts "String to sign: #{parts.join('')}"
            Digest::SHA256.hexdigest(parts.join(''))
          end

          def add_line_item(options={})
            requires!(options, :name, :unit_price, :amount, :quantity)
            options.assert_valid_keys([:description, :name, :unit_price, :amount, :quantity, :product_no])

            add_field("Items[#{@line_item_count}].ProductNo", options[:product_no] || "#{@line_item_count+1}")
            add_field("Items[#{@line_item_count}].Name", options[:name])
            add_field("Items[#{@line_item_count}].Description", options[:description]) if options[:description]
            add_field("Items[#{@line_item_count}].UnitPrice", format_amount(options[:unit_price]))
            # Item amount is total amount.
            add_field("Items[#{@line_item_count}].Amount", format_amount(options[:amount]))
            # Items are counted in multiples of 1000. Quantity 1 is represented as 1000
            add_field("Items[#{@line_item_count}].Quantity", options[:quantity].to_i * 1000)

            @line_item_count += 1
          end

          def format_amount(amount)
            amount.to_f.round
          end

          def amount
            sum = 0

            @line_item_count.times do |i|
              sum += @fields["Items[#{i}].Amount"].to_i
            end

            sum
          end

          def form_fields
            @fields['Signature'] = signature
            @fields['TotalAmount'] = amount

            @fields
          end

        end
      end
    end
  end
end
