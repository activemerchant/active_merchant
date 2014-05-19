module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CybersourceSecureAcceptance
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Security

          attr_accessor :line_item_count

          TRANSACTION_TYPES = [
            'authorization',
            'sale',
            'create_payment_token',
            'update_payment_token',
            'authorization,create_payment_token',
            'sale,create_payment_token',
            'authorization,update_payment_token',
            'sale,update_payment_token'
          ]
          ITEM_CODES = [
            'default',
            'adult_content',
            'coupon',
            'electronic_good',
            'electronic_software',
            'gift_certificate',
            'service',
            'subscription',
            'handling_only',
            'service',
            'shipping_and_handling',
            'shipping_only',
            'subscription'
          ]
          EXTRA_INFO_ITEM_CODES = [
            'adult_content',
            'coupon',
            'electronic_good',
            'electronic_software',
            'gift_certificate',
            'service',
            'subscription'
          ]

          def initialize(order, merchantnumber, options = {})
            @locale = options.delete(:locale)
            @endpoint = options.delete(:endpoint)
            @secret_key = options.delete(:credential3)

            # Used in tests
            @transaction_uuid_override = options.delete(:transaction_uuid_override)
            @signed_date_time_override = options.delete(:signed_date_time_override)

            super
            add_field('locale', @locale || 'en')

            @transaction_type = options[:transaction_type] || 'authorization'
            raise ArgumentError, 'invalid transaction_type' unless TRANSACTION_TYPES.include?(@transaction_type)

            add_field('transaction_type', @transaction_type)
            add_field('transaction_uuid', @transaction_uuid_override || transaction_uuid)
            add_field('signed_date_time', @signed_date_time_override || signed_date_time)
            @fields = Hash[@fields.sort]
            @line_item_count = 0
          end

          mapping :account, 'access_key'
          mapping :credential2, 'profile_id'

          # Optionally use these to override the return URLs defined in the Silent Order POST Profile.
          # (notify_url cannot be overriden)
          mapping :cancel_return_url, 'override_custom_cancel_page'
          mapping :return_url, 'override_custom_receipt_page'

          mapping :order, 'reference_number'
          mapping :amount, 'amount'
          mapping :tax, 'tax_amount'
          mapping :currency, 'currency'
          mapping :payment_method, 'payment_method'
          mapping :transaction_type, 'transaction_type'
          mapping :transaction_uuid, 'transaction_uuid'

          mapping :skip_decision_manager, 'skip_decision_manager'

          mapping :payment_token, 'payment_token'
          mapping :payment_token_comments, 'payment_token_comments'
          mapping :payment_token_title, 'payment_token_title'

          mapping :recurring, amount: 'recurring_amount',
                              frequency: 'recurring_frequency',
                              number_of_installments: 'recurring_number_of_installments',
                              start_date: 'recurring_start_date'

          mapping :signed_field_names, 'signed_field_names'
          mapping :unsigned_field_names, 'unsigned_field_names'

          mapping :locale, 'locale'

          mapping :customer, :first_name => 'bill_to_forename',
                             :last_name  => 'bill_to_surname',
                             :email      => 'bill_to_email',
                             :phone      => 'bill_to_phone',
                             :ip_address => 'customer_ip_address'

          mapping :billing_address, :city     => 'bill_to_address_city',
                                    :address1 => 'bill_to_address_line1',
                                    :address2 => 'bill_to_address_line2',
                                    :state    => 'bill_to_address_state',
                                    :zip      => 'bill_to_address_postal_code',
                                    :country  => 'bill_to_address_country',
                                    :company => 'bill_to_company_name',
                                    :company_tax_id => 'company_tax_id'

          def credential_based_url
            service_url = CybersourceSecureAcceptance.service_url

            return "#{service_url}/#{endpoint_path}"
          end

          def endpoint_path
            case @endpoint
            when :oneclick
              "oneclick/pay"
            when :create_token
              "token/create"
            when :update_token
              "token/update"
            when :silent_order
              "silent/pay"
            else
              "pay"
            end
          end

          def signed_field_names
            (@fields.keys + (['signed_field_names'])).sort.join(',')
          end

          def get_signature
            # All fields need to be represented in the _field_names lists, so we add those last.
            @fields['unsigned_field_names'] = '' # add_field rejects blank values.
            add_field('signed_field_names', signed_field_names)

            generate_signature @fields
          end

          def form_fields
            add_field('line_item_count', @line_item_count) if @line_item_count > 0
            @fields.merge('signature' => get_signature)
          end

          def transaction_uuid
            SecureRandom.hex(16)
          end

          def signed_date_time
            current_utc_xml_date_time = Time.now.utc.strftime "%Y-%m-%dT%H:%M:%S%z"
            current_utc_xml_date_time = current_utc_xml_date_time[0, current_utc_xml_date_time.length-5]
            current_utc_xml_date_time << 'Z'
            return current_utc_xml_date_time
          end

          # Need to format the amount to have 2 decimal places
          def amount=(money)
            cents = convert_to_cents(money)
            add_field mappings[:amount], sprintf("%.2f", BigDecimal.new(cents.to_s)/100)
          end

          # Add a line item to Cybersource Secure Acceptance.
          # Call line add_line_item {:code => 'default', :name => 'orange', :sku => 'ORA1', :unit_price => 30, :tax_amount => 'Y', :quantity => 3}
          # Note you can't pass in a negative unit price, and you can add an
          # optional :line_title => 'special name' if you don't want it to say
          # 'Item 1' or what not, the default coded here.
          # Cannot have a negative price, nor a name with "'s or $
          # You can use the :line_title for the product name and then :name for description, if desired
          def add_line_item(options)
            raise ArgumentError, 'needs name' unless options[:name]
              code = options[:code]
              name = options[:name]
              quantity = options[:quantity]
              sku = options[:sku]
              tax_amount = options[:tax_amount]
              unit_price = options[:unit_price]

              name = name[0..255]
              sku = sku[0..255] if sku

              if code
                # Code is optional, but must be in the item codes list if supplied.
                raise ArgumentError, 'invalid item code' unless ITEM_CODES.include?(code)

                if EXTRA_INFO_ITEM_CODES.include?(code) && (!quantity || !sku)
                  raise ArgumentError, "quantity and sku are required for product code '#{code}'"
                end
              end

              if @line_item_count == 49
                # Add a note that there are more items -- CS doesn't accept more than 50.
                add_field "item_#{@line_item_count}_name", 'There are 1 additional line item(s)...'


                # Make sure that the total amounts still add up.
                quantity ||= 1

                if tax_amount
                  tax_amount_cents = convert_to_cents(tax_amount) * quantity
                  tax_amount = sprintf("%.2f", BigDecimal.new(tax_amount_cents.to_s)/100)
                end

                if unit_price
                  unit_price_cents = convert_to_cents(unit_price) * quantity
                  unit_price = sprintf("%.2f", BigDecimal.new(unit_price_cents.to_s)/100)
                end

                add_field "item_#{@line_item_count}_tax_amount", tax_amount if tax_amount
                add_field "item_#{@line_item_count}_unit_price", unit_price if unit_price
                add_field "item_#{@line_item_count}_code", 'default'
                add_field "item_#{@line_item_count}_quantity", 1

                @additional_line_item_count = 1
                @line_item_count += 1
              elsif @line_item_count >= 50

                @fields['item_49_name'] = @fields['item_49_name'].gsub(/(\d+)/, (@additional_line_item_count+1).to_s)

                # Make sure that the total amounts still add up.
                quantity ||= 1
                if tax_amount
                  old_tax_amount_cents = (BigDecimal.new(@fields['item_49_tax_amount'])*100).to_i || 0

                  tax_amount_cents = (convert_to_cents(tax_amount) * quantity) + old_tax_amount_cents
                  tax_amount = sprintf("%.2f", BigDecimal.new(tax_amount_cents.to_s)/100)
                end
                if unit_price
                  old_unit_price_cents = (BigDecimal.new(@fields['item_49_unit_price'])*100).to_i || 0

                  unit_price_cents = (convert_to_cents(unit_price) * quantity) + old_unit_price_cents
                  unit_price = sprintf("%.2f", BigDecimal.new(unit_price_cents.to_s)/100)
                end

                @fields['item_49_tax_amount'] = tax_amount if tax_amount
                @fields['item_49_unit_price'] = unit_price if unit_price

                @additional_line_item_count += 1
                # Max allowed value for line_item count is 50
                @line_item_count = 50
              else
                if tax_amount
                  tax_amount_cents = convert_to_cents(tax_amount)
                  tax_amount = sprintf("%.2f", BigDecimal.new(tax_amount_cents.to_s)/100)
                end

                if unit_price
                  unit_price_cents = convert_to_cents(unit_price)
                  unit_price = sprintf("%.2f", BigDecimal.new(unit_price_cents.to_s)/100)
                end

                add_field "item_#{@line_item_count}_name", name
                add_field "item_#{@line_item_count}_tax_amount", tax_amount
                add_field "item_#{@line_item_count}_unit_price", unit_price
                add_field "item_#{@line_item_count}_code", code
                add_field "item_#{@line_item_count}_quantity", quantity
                add_field "item_#{@line_item_count}_sku", sku
                @line_item_count += 1
              end
          end

          private

          def convert_to_cents money
            cents = money.respond_to?(:cents) ? money.cents : money
            if money.is_a?(String) or cents.to_i < 0
              raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.'
            end

            return cents
          end
        end
      end
    end
  end
end
