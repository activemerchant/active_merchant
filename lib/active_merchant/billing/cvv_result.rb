module ActiveMerchant
  module Billing
    # Result of the Card Verification Value check
    # http://www.bbbonline.org/eExport/doc/MerchantGuide_cvv2.pdf
    class CVVResult
      
      CODES = {
        'M'  =>  'Match',
        'N'  =>  'No Match',
        'P'  =>  'Not Processed',
        'S'  =>  'Should have been present',
        'U'  =>  'Issuer unable to process request'
      }
      
      MATCH = {
        'M' => :match,
        'N' => :no_match,
        'P' => :unavailable,
        'S' => :no_match,
        'U' => :unavailable
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
        match == :no_match
      end
      
      def to_hash
        {
          'code' => code,
          'message' => message,
          'match' => (match && match.to_s)
        }
      end
    end
  end
end