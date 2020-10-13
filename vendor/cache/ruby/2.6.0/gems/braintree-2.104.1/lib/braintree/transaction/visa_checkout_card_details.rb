module Braintree
  class Transaction
    class VisaCheckoutCardDetails # :nodoc:
      include BaseModule

      attr_reader :bin
      attr_reader :call_id
      attr_reader :card_type
      attr_reader :cardholder_name
      attr_reader :commercial
      attr_reader :country_of_issuance
      attr_reader :customer_location
      attr_reader :debit
      attr_reader :durbin_regulated
      attr_reader :expiration_month
      attr_reader :expiration_year
      attr_reader :healthcare
      attr_reader :image_url
      attr_reader :issuing_bank
      attr_reader :last_4
      attr_reader :payroll
      attr_reader :prepaid
      attr_reader :product_id
      attr_reader :token

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end

      def expiration_date
        "#{expiration_month}/#{expiration_year}"
      end

      def inspect
        attr_order = [:token, :bin, :last_4, :card_type, :expiration_date, :cardholder_name, :customer_location, :prepaid,
        :healthcare, :durbin_regulated, :debit, :commercial, :payroll, :product_id, :country_of_issuance, :issuing_bank, :image_url, :call_id]
        formatted_attrs = attr_order.map do |attr|
          "#{attr}: #{send(attr).inspect}"
        end
        "#<#{formatted_attrs.join(", ")}>"
      end

      def masked_number
        "#{bin}******#{last_4}"
      end
    end
  end
end
