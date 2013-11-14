module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OrbitalGateway < Gateway
      # Unfortunately, Orbital uses their own special codes for AVS responses
      # that are different than the standard codes defined in
      # <tt>ActiveMerchant::Billing::AVSResult</tt>.
      #
      # This class encapsulates the response codes shown on page 240 of their spec:
      # http://download.chasepaymentech.com/docs/orbital/orbital_gateway_xml_specification.pdf
      #
      class AVSResult < ActiveMerchant::Billing::AVSResult
        CODES = {
            '1'  => 'No address supplied',
            '2'  => 'Bill-to address did not pass Auth Host edit checks',
            '3'  => 'AVS not performed',
            '4'  => 'Issuer does not participate in AVS',
            '5'  => 'Edit-error - AVS data is invalid',
            '6'  => 'System unavailable or time-out',
            '7'  => 'Address information unavailable',
            '8'  => 'Transaction Ineligible for AVS',
            '9'  => 'Zip Match/Zip 4 Match/Locale match',
            'A'  => 'Zip Match/Zip 4 Match/Locale no match',
            'B'  => 'Zip Match/Zip 4 no Match/Locale match',
            'C'  => 'Zip Match/Zip 4 no Match/Locale no match',
            'D'  => 'Zip No Match/Zip 4 Match/Locale match',
            'E'  => 'Zip No Match/Zip 4 Match/Locale no match',
            'F'  => 'Zip No Match/Zip 4 No Match/Locale match',
            'G'  => 'No match at all',
            'H'  => 'Zip Match/Locale match',
            'J'  => 'Issuer does not participate in Global AVS',
            'JA' => 'International street address and postal match',
            'JB' => 'International street address match. Postal code not verified',
            'JC' => 'International street address and postal code not verified',
            'JD' => 'International postal code match. Street address not verified',
            'M1' => 'Cardholder name matches',
            'M2' => 'Cardholder name, billing address, and postal code matches',
            'M3' => 'Cardholder name and billing code matches',
            'M4' => 'Cardholder name and billing address match',
            'M5' => 'Cardholder name incorrect, billing address and postal code match',
            'M6' => 'Cardholder name incorrect, billing postal code matches',
            'M7' => 'Cardholder name incorrect, billing address matches',
            'M8' => 'Cardholder name, billing address and postal code are all incorrect',
            'N3' => 'Address matches, ZIP not verified',
            'N4' => 'Address and ZIP code not verified due to incompatible formats',
            'N5' => 'Address and ZIP code match (International only)',
            'N6' => 'Address not verified (International only)',
            'N7' => 'ZIP matches, address not verified',
            'N8' => 'Address and ZIP code match (International only)',
            'N9' => 'Address and ZIP code match (UK only)',
            'R'  => 'Issuer does not participate in AVS',
            'UK' => 'Unknown',
            'X'  => 'Zip Match/Zip 4 Match/Address Match',
            'Z'  => 'Zip Match/Locale no match',
        }

        # Map vendor's AVS result code to a postal match code
        ORBITAL_POSTAL_MATCH_CODE = {
            'Y' => %w( 9 A B C H JA JD M2 M3 M5 N5 N8 N9 X Z ),
            'N' => %w( D E F G M8 ),
            'X' => %w( 4 J R ),
            nil => %w( 1 2 3 5 6 7 8 JB JC M1 M4 M6 M7 N3 N4 N6 N7 UK )
        }.inject({}) do |map, (type, codes)|
          codes.each { |code| map[code] = type }
          map
        end

        # Map vendor's AVS result code to a street match code
        ORBITAL_STREET_MATCH_CODE = {
            'Y' => %w( 9 B D F H JA JB M2 M4 M5 M6 M7 N3 N5 N7 N8 N9 X ),
            'N' => %w( A C E G M8 Z ),
            'X' => %w( 4 J R ),
            nil => %w( 1 2 3 5 6 7 8 JC JD M1 M3 N4 N6 UK )
        }.inject({}) do |map, (type, codes)|
          codes.each { |code| map[code] = type }
          map
        end

        def self.messages
          CODES
        end

        def initialize(code)
          @code = code.to_s.strip.upcase unless code.blank?
          if @code
            @message      = CODES[@code]
            @postal_match = ORBITAL_POSTAL_MATCH_CODE[@code]
            @street_match = ORBITAL_STREET_MATCH_CODE[@code]
          end
        end
      end
    end
  end
end
