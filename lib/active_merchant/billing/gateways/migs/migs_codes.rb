module ActiveMerchant
  module Billing
    module MigsCodes
      TXN_RESPONSE_CODES = {
        '?' => 'Response Unknown',
        '0' => 'Transaction Successful',
        '1' => 'Transaction Declined - Bank Error',
        '2' => 'Bank Declined Transaction',
        '3' => 'Transaction Declined - No Reply from Bank',
        '4' => 'Transaction Declined - Expired Card',
        '5' => 'Transaction Declined - Insufficient funds',
        '6' => 'Transaction Declined - Error Communicating with Bank',
        '7' => 'Payment Server Processing Error - Typically caused by invalid input data such as an invalid credit card number. Processing errors can also occur',
        '8' => 'Transaction Declined - Transaction Type Not Supported',
        '9' => 'Bank Declined Transaction (Do not contact Bank)',
        'A' => 'Transaction Aborted',
        'C' => 'Transaction Cancelled',
        'D' => 'Deferred Transaction',
        'E' => 'Issuer Returned a Referral Response',
        'F' => '3D Secure Authentication Failed',
        'I' => 'Card Security Code Failed',
        'L' => 'Shopping Transaction Locked (This indicates that there is another transaction taking place using the same shopping transaction number)',
        'N' => 'Cardholder is not enrolled in 3D Secure (Authentication Only)',
        'P' => 'Transaction is Pending',
        'R' => 'Retry Limits Exceeded, Transaction Not Processed',
        'S' => 'Duplicate OrderInfo used. (This is only relevant for Payment Servers that enforce the uniqueness of this field)',
        'U' => 'Card Security Code Failed'
      }

      ISSUER_RESPONSE_CODES = {
        '00' => 'Approved',
        '01' => 'Refer to Card Issuer',
        '02' => 'Refer to Card Issuer',
        '03' => 'Invalid Merchant',
        '04' => 'Pick Up Card',
        '05' => 'Do Not Honor',
        '07' => 'Pick Up Card',
        '12' => 'Invalid Transaction',
        '14' => 'Invalid Card Number (No such Number)',
        '15' => 'No Such Issuer',
        '33' => 'Expired Card',
        '34' => 'Suspected Fraud',
        '36' => 'Restricted Card',
        '39' => 'No Credit Account',
        '41' => 'Card Reported Lost',
        '43' => 'Stolen Card',
        '51' => 'Insufficient Funds',
        '54' => 'Expired Card',
        '57' => 'Transaction Not Permitted',
        '59' => 'Suspected Fraud',
        '62' => 'Restricted Card',
        '65' => 'Exceeds withdrawal frequency limit',
        '91' => 'Cannot Contact Issuer'
      }

      VERIFIED_3D_CODES = {
        'Y' => 'The cardholder was successfully authenticated.',
        'E' => 'The cardholder is not enrolled.',
        'N' => 'The cardholder was not verified.',
        'U' => 'The cardholder\'s Issuer was unable to authenticate due to a system error at the Issuer.',
        'F' => 'An error exists in the format of the request from the merchant. For example, the request did not contain all required fields, or the format of some fields was invalid.',
        'A' => 'Authentication of your Merchant ID and Password to the Directory Server Failed (see "What does a Payment Authentication Status of "A" mean?" on page 85).',
        'D' => 'Error communicating with the Directory Server, for example, the Payment Server could not connect to the directory server or there was a versioning mismatch.',
        'C' => 'The card type is not supported for authentication.',
        'M' => 'This indicates that attempts processing was used. Verification is marked with status M - ACS attempts processing used. Payment is performed with authentication. Attempts is when a cardholder has successfully passed the directory server but decides not to continue with the authentication process and cancels.',
        'S' => 'The signature on the response received from the Issuer could not be validated. This should be considered a failure.',
        'T' => 'ACS timed out. The Issuer\'s ACS did not respond to the Authentication request within the time out period.',
        'P' => 'Error parsing input from Issuer.',
        'I' => 'Internal Payment Server system error. This could be caused by a temporary DB failure or an error in the security module or by some error in an internal system.'
      }

      class CreditCardType
        attr_accessor :am_code, :migs_code, :migs_long_code, :name
        def initialize(am_code, migs_code, migs_long_code, name)
          @am_code        = am_code
          @migs_code      = migs_code
          @migs_long_code = migs_long_code
          @name           = name
        end
      end

      CARD_TYPES = [
        # The following are 4 different representations of credit card types
        # am_code: The active merchant code
        # migs_code: Used in response for purchase/authorize/status
        # migs_long_code: Used to pre-select card for server_purchase_url
        # name: The nice display name
        %w(american_express AE Amex             American\ Express),
        %w(diners_club      DC Dinersclub       Diners\ Club),
        %w(jcb              JC JCB              JCB\ Card),
        %w(maestro          MS Maestro          Maestro\ Card),
        %w(master           MC Mastercard       MasterCard),
        %w(na               PL PrivateLabelCard Private\ Label\ Card),
        %w(visa             VC Visa             Visa\ Card')
      ].map do |am_code, migs_code, migs_long_code, name|
        CreditCardType.new(am_code, migs_code, migs_long_code, name)
      end
    end
  end
end
