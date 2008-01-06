module ActiveMerchant
  module Billing 
    # Implements the Address Verification System
    # https://www.wellsfargo.com/downloads/pdf/biz/merchant/visa_avs.pdf
    # http://en.wikipedia.org/wiki/Address_Verification_System
    # http://apps.cybersource.com/library/documentation/dev_guides/CC_Svcs_IG/html/app_avs_cvn_codes.htm#app_AVS_CVN_codes_7891_48375
    # http://imgserver.skipjack.com/imgServer/5293710/AVS%20and%20CVV2.pdf
    class AVSResult
      MATCH = {
        :full        => %w( D J M Q V X Y ),
        :partial     => %w( A B F H K L P O T W Z ),
        :none        => %w( N ),
        :unavailable => %w( C E G I R S U )
      }.inject({}) do |map, (type, codes)|
        codes.each { |code| map[code] = type }
        map
      end
      
      CODES = {
        'A' => 'Street address matches, but 5-digit and 9-digit postal code do not match.',
        'B' => 'Street address matches, but postal code not verified.',
        'C' => 'Street address and postal code do not match.',
        'D' => 'Street address and postal code match.',
        'E' => 'AVS data is invalid or AVS is not allowed for this card type.',
        'F' => 'Card member’s name does not match, but billing postal code matches.',
        'G' => 'Non-U.S. issuing bank does not support AVS.',
        'H' => 'Card member’s name does not match. Street address and postal code match.',
        'I' => 'Address not verified.',
        'J' => 'Card member’s name, billing address, and postal code match. Shipping information verified and chargeback protection guaranteed through the Fraud Protection Program.',
        'K' => 'Card member’s name matches but billing address and billing postal code do not match.',
        'L' => 'Card member’s name and billing postal code match, but billing address does not match.',
        'M' => 'Street address and postal code match.',
        'N' => 'Street address and postal code do not match.',
        'O' => 'Card member’s name and billing address match, but billing postal code does not match.',
        'P' => 'Postal code matches, but street address not verified.',
        'Q' => 'Card member’s name, billing address, and postal code match. Shipping information verified but chargeback protection not guaranteed.',
        'R' => 'System unavailable.',
        'S' => 'U.S.-issuing bank does not support AVS.',
        'T' => 'Card member’s name does not match, but street address matches.',
        'U' => 'Address information unavailable.',
        'V' => 'Card member’s name, billing address, and billing postal code match.',
        'W' => 'Street address does not match, but 9-digit postal code matches.',
        'X' => 'Street address and 9-digit postal code match.',
        'Y' => 'Street address and 5-digit postal code match.',
        'Z' => 'Street address does not match, but 5-digit postal code matches.'
      }
      
      attr_reader :code, :message, :match
      
      def initialize(code)
        if !code.blank?
          @code = code.upcase
          @message = CODES[@code]
          @match = MATCH[@code]
        end
      end
    
      def failure?
        [ :partial, :none ].include?(match)
      end
      
      def to_hash
        { 'code' => code,
          'message' => message,
          'match' => (match && match.to_s)
        }
      end
    end
  end
end