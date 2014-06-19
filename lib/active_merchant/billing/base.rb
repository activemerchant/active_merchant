module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Base
      # Set ActiveMerchant gateways in test mode.
      #
      #   ActiveMerchant::Billing::Base.gateway_mode = :test
      mattr_accessor :gateway_mode

      # Set ActiveMerchant integrations in test mode.
      #
      #   ActiveMerchant::Billing::Base.integration_mode = :test
      def self.integration_mode=(mode)
        ActiveMerchant.deprecated(OFFSITE_PAYMENT_EXTRACTION_MESSAGE)
        @@integration_mode = mode
      end

      def self.integration_mode
        ActiveMerchant.deprecated(OFFSITE_PAYMENT_EXTRACTION_MESSAGE)
        @@integration_mode
      end

      # Set both the mode of both the gateways and integrations
      # at once
      mattr_reader :mode

      def self.mode=(mode)
        @@mode = mode
        self.gateway_mode = mode
        @@integration_mode = mode
      end

      self.mode = :production

      # Return the matching gateway for the provider
      # * <tt>bogus</tt>: BogusGateway - Does nothing (for testing)
      # * <tt>moneris</tt>: MonerisGateway
      # * <tt>authorize_net</tt>: AuthorizeNetGateway
      # * <tt>trust_commerce</tt>: TrustCommerceGateway
      #
      #   ActiveMerchant::Billing::Base.gateway('moneris').new
      def self.gateway(name)
        name_str = name.to_s.strip.downcase

        raise(ArgumentError, 'A gateway provider must be specified') if name_str.blank?

        begin
          Billing.const_get("#{name_str}_gateway".camelize)
        rescue
          raise ArgumentError, "The specified gateway is not valid (#{name_str})"
        end
      end

      # Return the matching integration module
      # You can then get the notification from the module
      # * <tt>bogus</tt>: Bogus - Does nothing (for testing)
      # * <tt>chronopay</tt>: Chronopay
      # * <tt>paypal</tt>: Paypal
      #
      #   chronopay = ActiveMerchant::Billing::Base.integration('chronopay')
      #   notification = chronopay.notification(raw_post)
      #
      def self.integration(name)
        Billing::Integrations.const_get("#{name.to_s.downcase}".camelize)
      end

      # A check to see if we're in test mode
      def self.test?
        self.gateway_mode == :test
      end
    end
  end
end
