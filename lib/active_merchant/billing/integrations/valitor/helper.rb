require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Valitor
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include RequiresParameters
          
          DEFAULT_SUCCESS_TEXT = "The transaction has been completed."
          
          def initialize(order, account, options={})
            options[:currency] ||= 'ISK'
            super
            # This field must be zero
            add_field 'AuthorizationOnly', '0'
            add_field 'DisplayBuyerInfo', '0'
            @security_number = options[:credential2]
            @amount          = options[:amount]
            @order           = order
          end
          
          mapping :account, 'MerchantID'
          mapping :currency, 'Currency'

          mapping :order, 'ReferenceNumber'

          mapping :notify_url, 'PaymentSuccessfulServerSideURL'
          mapping :return_url, 'PaymentSuccessfulURL'
          mapping :cancel_return_url, 'PaymentCancelledURL'
          
          mapping :success_text, 'PaymentSuccessfulURLText'
          
          mapping :language, 'Language'
          
          def collect_customer_info
            add_field 'DisplayBuyerInfo', '1'
          end
          
          def product(id, options={})
            raise ArgumentError, "Product id #{id} is not an integer between 1 and 500" unless id.to_i > 0 && id.to_i <= 500
            requires!(options, :amount, :description)
            options.assert_valid_keys([:description, :quantity, :amount, :discount])

            add_field("Product_#{id}_Price", format_amount(options[:amount], @fields[mappings[:currency]]))
            add_field("Product_#{id}_Quantity", options[:quantity] || "1")
            
            add_field("Product_#{id}_Description", options[:description]) if options[:description]
            add_field("Product_#{id}_Discount", options[:discount] || '0')
            
            @products ||= []
            @products << id.to_i
          end
          
          def signature
            raise ArgumentError, "Security number not set" unless @security_number
            parts = [@security_number, @fields['AuthorizationOnly']]
            @products.sort.uniq.each do |id|
              parts.concat(["Product_#{id}_Quantity", "Product_#{id}_Price", "Product_#{id}_Discount"].collect{|e| @fields[e]})
            end if @products
            parts.concat(%w(MerchantID ReferenceNumber PaymentSuccessfulURL PaymentSuccessfulServerSideURL Currency).collect{|e| @fields[e]})
            Digest::MD5.hexdigest(parts.compact.join(''))
          end

          def form_fields
            product(1, :amount => @amount, :description => @order) if Array(@products).empty?
            @fields[mappings[:success_text]] ||= DEFAULT_SUCCESS_TEXT
            @fields.merge('DigitalSignature' => signature)
          end
          
          def format_amount(amount, currency)
            Gateway::CURRENCIES_WITHOUT_FRACTIONS.include?(currency) ? amount.to_f.round : sprintf("%.2f", amount)
          end
        end
      end
    end
  end
end
