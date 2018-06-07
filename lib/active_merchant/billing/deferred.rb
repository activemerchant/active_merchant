require 'date'
require 'active_merchant/billing/model'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # A +Deferred+ object represents a deferred payment coupon, and is capable of validating the various
    # data associated with these.
    #
    # At the moment, the following deferred types are supported:
    #
    # Argentina
    # * PAGOFACIL
    # * RAPIPAGO
    # * COBRO_EXPRESS
    # * BAPRO
    # * RIPSA
    #
    # Brasil
    # * BOLETO_BANCARIO
    #
    # Chile
    # * MULTICAJA
    #
    # Colombia
    # * BALOTO
    # * BANK_REFERENCED
    # * EFECTY
    # * OTHERS_CASH
    #
    # Mexico
    # * OXXO
    # * BANK_REFERENCED
    # * SEVEN_ELEVEN
    # * OTHERS_CASH_MX
    #
    # Peru
    # * BCP
    # * PAGOEFECTIVO
    #
    # == Testing
    # Payu latam provides a way to request test coupons to the sandbox but
    # `test` data option should be always in true in these cases.
    #
    class Deferred < Model
      # Returns or sets the expiry date for the payment.
      #
      # @return [Date]
      attr_accessor :expiration_date

      # Returns or sets the diferred provider brand.
      #
      # Valid card types are
      #
      # Colombia
      # * +'BALOTO'+
      # * +'EFECTY'+
      # Mexico
      # * +'OXXO'+
      # * +'SEVEN_ELEVEN'+
      # Argentina
      # * +'RAPIPAGO'+
      # * +'PAGOFACIL'+
      # Brasil
      # * +'BOLETO_BANCARIO'+
      #
      # @return (String) the diferred provider brand
      attr_accessor :brand

      # Returns or sets the first name of the card holder.
      #
      # @return [String]
      attr_accessor :first_name

      # Returns or sets the last name of the card holder.
      #
      # @return [String]
      attr_accessor :last_name

      # Returns the full name of the card holder.
      #
      # @return [String] the full name of the card holder
      def name
        "#{first_name} #{last_name}".strip
      end

      # Returns the brand method deferred.
      #
      # @return [Boolean] if the brand method is deferred or not.
      def deferred?
        true
      end

      # Validates the credit card details.
      #
      # Any validation errors are added to the {#errors} attribute.
      def validate
        errors_hash(validate_essential_attributes)
      end

      private

      def validate_essential_attributes #:nodoc:
        errors = []

        errors << [:first_name, 'is required'] if first_name.blank?
        errors << [:last_name, 'is required']  if last_name.blank?
        errors << [:brand, 'is required']      if brand.blank?

        if expiration_date.blank?
          errors << [:expiration_date, 'is required']
        elsif expiration_date <= Date.today
          errors << [:expiration_date, 'expired']
        end

        errors
      end
    end
  end
end
