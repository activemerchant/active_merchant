module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Base
      GATEWAY_MODE_DEPRECATION_MESSAGE = 'Base#gateway_mode is deprecated in favor of Base#mode and will be removed in a future version'

      # Set ActiveMerchant gateways in test mode.
      #
      #   ActiveMerchant::Billing::Base.mode = :test
      mattr_accessor :mode

      def self.gateway_mode=(mode)
        ActiveMerchant.deprecated(GATEWAY_MODE_DEPRECATION_MESSAGE)
        @@mode = mode
      end

      def self.gateway_mode
        ActiveMerchant.deprecated(GATEWAY_MODE_DEPRECATION_MESSAGE)
        @@mode
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
        mode == :test
      end
    end
  end
end
