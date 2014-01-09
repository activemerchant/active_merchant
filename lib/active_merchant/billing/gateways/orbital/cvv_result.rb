module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OrbitalGateway < Gateway
      # Unfortunately, Orbital uses their own special codes for CVV responses
      # that are different than the standard codes defined in
      # <tt>ActiveMerchant::Billing::CVVResult</tt>.
      #
      # This class encapsulates the response codes shown on page 255 of their spec:
      # http://download.chasepaymentech.com/docs/orbital/orbital_gateway_xml_specification.pdf
      #
      class CVVResult < ActiveMerchant::Billing::CVVResult
        MESSAGES = {
          'M' => 'Match',
          'N' => 'No match',
          'P' => 'Not processed',
          'S' => 'Should have been present',
          'U' => 'Unsupported by issuer/Issuer unable to process request',
          'I' => 'Invalid',
          'Y' => 'Invalid',
          ''  => 'Not applicable'
        }

        def self.messages
          MESSAGES
        end

        def initialize(code)
          @code = code.blank? ? '' : code.upcase
          @message = MESSAGES[@code]
        end
      end
    end
  end
end
