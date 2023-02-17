module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module CyberSourceCommon
      def check_billing_field_value(default, submitted)
        if submitted.nil?
          nil
        elsif submitted.blank?
          default
        else
          submitted
        end
      end

      def address_names(address_name, payment_method)
        names = split_names(address_name)
        return names if names.any?(&:present?)

        [
          payment_method&.first_name,
          payment_method&.last_name
        ]
      end

      def lookup_country_code(country_field)
        return unless country_field.present?

        country_code = Country.find(country_field)
        country_code&.code(:alpha2)
      end
    end
  end
end
