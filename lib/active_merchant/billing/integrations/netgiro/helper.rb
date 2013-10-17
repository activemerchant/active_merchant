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
            @shipping = 0
            @handling = 0
            @discount = 0
          end

          def currency(symbol)
            # Netgiro only supports ISK at the moment
            raise ArgumentError, "Unsupported currency" unless SUPPORTED_CURRENCIES.include?(symbol)
            # add_field mappings[:currency], symbol
          end

          def signature
            raise ArgumentError, "Secret key is not set" unless @secret
            parts = [@secret, @fields['OrderId'], amount, @fields['ApplicationID']]
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

          def payment_option(option)
            # Netgiro supports 3 payment types
            # 1: standard payment within 14 days
            # 2: user will be presented with the option to pay in multiple installments
            # 3: user will be presented with the option to pay in multiple installments, where 
            #    seller includes interests in the sale price
            raise ArgumentError, "Payment option should be 1, 2 or 3" unless [1,2,3].include?(option)
            add_field("PaymentOption", option)
          end

          def max_number_of_installments(max)
            # This parameter controls the maximum number of installments the user can choose
            # to pay with. Please note that Netgiro determines the number of installments 
            # based on minimum monthly rate and other factors, so the actual number of 
            # installments offered to the user can be smaller than specified with this 
            # parameter, but it will never be bigger
            add_field("MaxNumberOfInstallments", max)
          end

          def add_shipping(amount)
            add_field("ShippingAmount", format_amount(amount))
            @shipping = amount
          end

          def add_handling(amount)
            add_field("HandlingAmount", format_amount(amount))
            @handling = amount
          end

          def add_discount(amount)
            raise ArgumentError, "Discount should be positive number" if amount < 0
            add_field("DiscountAmount", format_amount(amount))
            @discount = amount
          end

          def return_customer_info(value)
            raise ArgumentError, "Return customer info option should be a boolean." unless !!value == value
            add_field("ReturnCustomerInfo", value.to_s)
          end

          def format_amount(amount)
            amount.to_f.round
          end

          def amount
            sum = 0

            @line_item_count.times do |i|
              sum += @fields["Items[#{i}].Amount"].to_i
            end

            if @fields.keys.include? "ShippingAmount"
              sum += @shipping
            end
            if @fields.keys.include? "HandlingAmount"
              sum += @handling
            end
            if @fields.keys.include? "DiscountAmount"
              sum -= @discount
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
