require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module SagePayForm
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          class CryptError < StandardError; end

          include Encryption
          
          def initialize(post_data, options)
            super
            load_crypt_params(params['crypt'], options[:credential2])
          end
          
          # Was the transaction complete?
          def complete?
            status_code == 'OK'
          end

          # Was the transaction cancelled?
          # Unfortunately, we can't distinguish "user abort" from "idle too long".
          def cancelled?
            status_code == 'ABORT'
          end

          # Text version of #complete?, since we don't support Pending.
          def status
            complete? ? 'Completed' : 'Failed'
          end

          # Status of transaction. List of possible values:
          # <tt>OK</tt>:: Transaction completed successfully.
          # <tt>NOTAUTHED</tt>:: Incorrect card details / insufficient funds.
          # <tt>MALFORMED</tt>:: Invalid input data.
          # <tt>INVALID</tt>:: Valid input data, but some fields are incorrect.
          # <tt>ABORT</tt>:: User hit cancel button or went idle for 15+ minutes.
          # <tt>REJECTED</tt>:: Rejected by account fraud screening rules.
          # <tt>AUTHENTICATED</tt>:: Authenticated card details secured at SagePay.
          # <tt>REGISTERED</tt>:: Non-authenticated card details secured at SagePay.
          # <tt>ERROR</tt>:: Problem internal to SagePay.
          def status_code
            params['Status']
          end

          # Check this if #completed? is false.
          def message
            params['StatusDetail']
          end

          # Vendor-supplied code (:order mapping).
          def item_id
            params['VendorTxCode']
          end

          # Internal SagePay code, typically "{LONG-UUID}".
          def transaction_id
            params['VPSTxId']
          end

          # Authorization number (only if #completed?).
          def auth_id
            params['TxAuthNo']
          end

          # Total amount (no fees).
          def gross
            params['Amount'].gsub(/,(?=\d{3}\b)/, '')
          end
          
          # AVS and CV2 check results.  Possible values:
          # <tt>ALL MATCH</tt>::
          # <tt>SECURITY CODE MATCH ONLY</tt>::
          # <tt>ADDRESS MATCH ONLY</tt>::
          # <tt>NO DATA MATCHES</tt>::
          # <tt>DATA NOT CHECKED</tt>::
          def avs_cv2_result
            params['AVSCV2']
          end
          
          # Numeric address check.  Possible values:
          # <tt>NOTPROVIDED</tt>::
          # <tt>NOTCHECKED</tt>::
          # <tt>MATCHED</tt>::
          # <tt>NOTMATCHED</tt>::          
          def address_result
            params['AddressResult']
          end
          
          # Post code check.  Possible values:
          # <tt>NOTPROVIDED</tt>::
          # <tt>NOTCHECKED</tt>::
          # <tt>MATCHED</tt>::
          # <tt>NOTMATCHED</tt>::          
          def post_code_result
            params['PostCodeResult']
          end

          # CV2 code check.  Possible values:
          # <tt>NOTPROVIDED</tt>::
          # <tt>NOTCHECKED</tt>::
          # <tt>MATCHED</tt>::
          # <tt>NOTMATCHED</tt>::          
          def cv2_result
            params['CV2Result']
          end

          # Was the Gift Aid box checked?
          def gift_aid?
            params['GiftAid'] == '1'
          end

          # Result of 3D Secure checks.  Possible values:
          # <tt>OK</tt>:: Authenticated correctly.
          # <tt>NOTCHECKED</tt>:: Authentication not performed.
          # <tt>NOTAVAILABLE</tt>:: Card not auth-capable, or auth is otherwise impossible.
          # <tt>NOTAUTHED</tt>:: User failed authentication.
          # <tt>INCOMPLETE</tt>:: Authentication unable to complete.
          # <tt>ERROR</tt>:: Unable to attempt authentication due to data / service errors.
          def buyer_auth_result
            params['3DSecureStatus']
          end

          # Encoded 3D Secure result code.
          def buyer_auth_result_code
            params['CAVV']
          end

          # Address confirmation status.  PayPal only.  Possible values:
          # <tt>NONE</tt>:: 
          # <tt>CONFIRMED</tt>:: 
          # <tt>UNCONFIRMED</tt>:: 
          def address_status
            params['AddressStatus']
          end

          # Payer verification.  Undocumented.
          def payer_verified?
            params['PayerStatus'] == 'VERIFIED'
          end
          
          # Credit card type.  Possible values:
          # <tt>VISA</tt>:: Visa
          # <tt>MC</tt>:: MasterCard
          # <tt>DELTA</tt>:: Delta
          # <tt>SOLO</tt>:: Solo
          # <tt>MAESTRO</tt>:: Maestro (UK and International)
          # <tt>UKE</tt>:: Visa Electron
          # <tt>AMEX</tt>:: American Express
          # <tt>DC</tt>:: Diners Club
          # <tt>JCB</tt>:: JCB
          # <tt>LASER</tt>:: Laser
          # <tt>PAYPAL</tt>:: PayPal
          def credit_card_type
            params['CardType']
          end

          # Last four digits of credit card.
          def credit_card_last_4_digits
            params['Last4Digits']
          end

          # Used by composition methods, but not supplied by SagePay.
          def currency
            nil
          end

          def test?
            false
          end
          
          def acknowledge      
            true
          end

          private

          def load_crypt_params(crypt, key)
            raise MissingCryptData if crypt.blank?
            raise MissingCryptKey  if key.blank?
            
            crypt_data = sage_decrypt(crypt.gsub(' ', '+'), key)
            raise InvalidCryptData unless crypt_data =~ /(^|&)Status=/

            params.clear            
            parse(crypt_data)
          end

          class MissingCryptKey  < CryptError
            def message
              'No merchant decryption key supplied'
            end
          end
          class MissingCryptData < CryptError
            def message
              'No data received from SagePay'
            end
          end
          class InvalidCryptData < CryptError
            def message
              'Invalid data received from SagePay'
            end
          end

        end
      end
    end
  end
end
