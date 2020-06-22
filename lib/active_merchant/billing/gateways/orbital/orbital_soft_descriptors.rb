module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OrbitalSoftDescriptors < Model
      PHONE_FORMAT_1 = /\A\d{3}-\d{3}-\d{4}\z/
      PHONE_FORMAT_2 = /\A\d{3}-\w{7}\z/

      # ==== Tampa PNS Soft Descriptors
      # The support for Soft Descriptors via the PNS Host is only for customers processing through Chase
      # Paymentech Canada.

      # Unlike Salem, the only value that gets passed on the cardholder statement is the Merchant Name field.
      # And for these customers, it is a maximum of 25 bytes of data.
      #
      # All other Soft Descriptor fields can optionally be sent, but will not be submitted to the settlement host
      # and will not display on the cardholder statement.

      attr_accessor :merchant_name, :product_description, :merchant_city, :merchant_phone, :merchant_url, :merchant_email

      def initialize(options = {})
        self.merchant_name = options[:merchant_name]
        self.merchant_city = options[:merchant_city]
        self.merchant_phone = options[:merchant_phone]
        self.merchant_url = options[:merchant_url]
        self.merchant_email = options[:merchant_email]
      end

      def validate
        errors = []

        errors << [:merchant_name, 'is required'] if self.merchant_name.blank?
        errors << [:merchant_name, 'is required to be 25 bytes or less'] if self.merchant_name.bytesize > 25

        errors << [:merchant_phone, 'is required to follow "NNN-NNN-NNNN" or "NNN-AAAAAAA" format'] if !empty?(self.merchant_phone) && !self.merchant_phone.match(PHONE_FORMAT_1) && !self.merchant_phone.match(PHONE_FORMAT_2)

        %i[merchant_email merchant_url].each do |attr|
          unless self.send(attr).blank?
            errors << [attr, 'is required to be 13 bytes or less'] if self.send(attr).bytesize > 13
          end
        end

        errors_hash(errors)
      end
    end
  end
end
