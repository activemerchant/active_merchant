require 'net/http'

module ActiveMerchant # Primary active_merchant module
  module Billing # Primary active_merchant billing module
    module Integrations # Primary active_merchant integrations module
      module Paydollar # The active_merchant's Paydollar module
        # Paydollar Notification class
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          # These are sample responses from Paydollar

          # -----------------------    VISA ----------------------
          #"prc=0&src=0&Ord=12345678&Ref=Order_PD_1000&PayRef=1154604&successcode=0&Amt=100.94&
          #Cur=344&Holder=testing card&AuthId=154604&AlertCode=R14&remark=&eci=07&payerAuth=U&
          #sourceIp=192.168.1.100&ipCountry=IN&payMethod=VISA&TxTime=2013-06-10 14:51:21.0&
          #panFirst4=4918&panLast4=5005&cardIssuingCountry=HK&channelType=SPC&MerchantId=1234
          #&secureHash=467593443fd1190575f91239fb533fa53ca01650"

          # -----------------------    MASTER ----------------------
          #"prc=0&src=0&Ord=12345678&Ref=Order_PD_1000&PayRef=1151801&successcode=0&Amt=100.94&
          #Cur=344&Holder=testing card&AuthId=151801&AlertCode=R14&remark=&eci=07&payerAuth=U&
          #sourceIp=192.168.1.100&ipCountry=IN&payMethod=Master&TxTime=2013-06-05 20:25:38.0&
          #panFirst4=5422&panLast4=0007&cardIssuingCountry=HK&channelType=SPC&MerchantId=1234&
          #secureHash=a256e74e7c7814a1f7483884ba1e08e88abc0da1"

          # Check if the payment is approved or NOT
          # @param secret_hash [String] The secure hash provided by Paydoller (applies only
          #     if registered for secure hash functionality), if not send nil 
          # @return [Boolean] Returns true if the payment is successful and the secure hash
          #     is valid (if applicable)
          def approved?(secret_hash)
            return (secret_hash ? generate_secure_hash(secret_hash) == secure_hash : true) if status == '0'
            false
          end

          # The primary response code is the main response code used for identifying
          # the authorization status of a payment transaction.
          #
          # - 0 Success
          # - 1 Rejected by Payment Bank
          # - 3 Rejected due to Payer Authentication Failure (3D)
          # - -1 Rejected due to Input Parameters Incorrect
          # - -2 Rejected due to Server Access Error
          # - -8 Rejected due to PayDollar Internal/Fraud Prevention Checking
          # - -9 Rejected by Host Access Error
          #
          # @return [String] The primary bank host status code
          def primary_bank_host_status_code
            params['prc']
          end

          # The secondary response code provides the detail description 
          # corresponding to the primary response code.
          # Return bank host status code (secondary)
          # 0 Success, other numbers indicate failure (see documentation)
          #
          # @return [String] The secondary bank host status code
          def secondary_bank_host_status_code
            params['src']
          end

          # Bank Reference
          # @return [String] The bank reference number
          def bank_reference_orderid
            params['Ord']
          end

          # The Holder Name of the Payment Account
          # @return [String] The card holder's name
          def holder_name
            params['Holder']
          end

          # Payment status
          # @return [String] 0- succeeded, 1- failure, Others- error
          def status
            params['successcode']
          end

          # Merchant‘s Order Reference Number
          # @return [String] Order number sent in the payment request
          def item_id
            params['Ref']
          end

          # PayDollar Payment Reference Number
          # @return [String] Paydollar reference number
          def paydollar_ref
            params['PayRef']  
          end

          # Transaction Amount
          # @return [String] The amount charged
          def gross
            params['Amt']
          end

          # Transaction Currency
          # @return [String] The currency for the amount charged
          def currency
            params['Cur']
          end

          # Approval Code
          # @return [String] Paydollar approval code
          def approval_code
            params['AuthId']
          end

          # ECI value (for 3D enabled Merchants)
          # @return [String] The ECI value (for 3D enabled Merchants)
          def eci
            params['eci']  
          end

          # Payer Authentication Status
          # - Y - Card is 3-D secure enrolled and authentication succeeds.
          # - N - Card is 3-D secure enrolled but authentication fails.
          # - P - 3-D Secure check is pending
          # - A - Card is not 3-D secure enrolled yet
          # - U - 3D-secure check is not processed.
          # @return [String] Payer authentication status
          def payer_auth_status
            params['payerAuth']
          end 

          # A remark field for you to store additional data that will not
          # show on the transaction web page
          # @return [String] Remarks
          def remark
            params['remark']
          end

          # The Alert Code
          # @return [String] The Alert Code, for e.g.
          # - R14 –IP Country not match with Issuing Country
          # - R 9 - In high risk country list
          def alert_code
            params['AlertCode']
          end

          # The merchant Id of transaction
          # @return [String] The merchant id initiating the transaction
          def merchant_id
            params['MerchantId']
          end

          # IP address of payer
          # @return [String] Public IP address of the payer's network
          def payer_ip
            params['sourceIp']
          end

          # Country of payer
          #- if country is on high risk country list, an asterisk will be shown (e.g. MY*)
          # @return [String] Country of payer ( e.g. HK)
          def ip_country
            params['ipCountry']
          end

          # Payment method 
          # @return [String] Payment method, e.g. VISA, Master, Diners, JCB, AMEX)
          def payment_method
            params['payMethod']
          end

          # Transaction time
          # @return [String] The format is (YYYY-MM-DD HH:MI:SS.0) for e.g. 2013-06-05 19:47:26.0
          def transaction_time
            params['TxTime']
          end

          # First 4 digit of card 
          #     NOTE: Only for approved merchant only
          # @return [String] The first 4 digits of the card
          def pan_first4
            params['panFirst4']
          end

          # Last 4 digit of card 
          #     NOTE: Only for approved merchant only
          # @return [String] The last 4 digits of the card
          def pan_last4
            params['panLast4']  
          end

          # Hash value of card
          #     NOTE: Applies to approved merchant only
          # @return [String] Hash value of the card
          def account_hash
            params['accountHash']  
          end

          # Hash function of card
          #     NOTE: Applies to approved merchant only
          # @return [String] Hash function of the card, e.g. SHA-1
          def account_hash_algo
            params['accountHashAlgo']  
          end

          # Card Issuing Country Code
          # - If country is on high risk country list, an asterisk will be shown (e.g. MY*)
          # - If the card issuing country of credit card is undefined, “- -“ will be shown.
          #     Please refer to Appendix A “List of Country Code” in Paydollar documentation
          # @return [String] Card Issuing Country Code (e.g. HK)
          def card_issuing_country
            params['cardIssuingCountry']
          end

          # Channel Type
          # @return [String] One of the valid channel types
          #   - SPC – Client Post Through Browser
          #   - DPC – Direct Client Side Connection
          #   - DPS – Server Side Direct Connection
          #   - SCH – Schedule Payment
          #   - DPL – Direct Payment Link Connection
          #   - MOT – Motor Connection
          #   - RTL – RetailPay Connection
          #   - BPP – Batch Payment Process
          #   - MOB – Mobile Payment Connection
          def channel_type
            params['channelType']
          end

          # Air Ticket Number
          # @return [String] Air ticket number
          def air_ticket_number
            params['airline_ticketNumber']
          end

          # Secure hash
          # @return [String] The secure hash received in the response from Paydollar
          def secure_hash
            params['secureHash'] ? params['secureHash'].upcase : ""
          end

          # The data feed page must meet the following requirements:
          # - 1) Print ‘OK’ in HTML when data captured (ACK message)
          # - 2) Make Sure to Print ‘OK’ for acknowledge to Paydollar system
          #   first then do the rest of your system process, if something wrong
          #   with your system process (i.e. download photo, ring tone
          #   problem) you can send a void request to Paydollar system, for more 
          #   details please refer to API guide and contact our technical staff.
          # @return [String] The acknowledgement string expected by Paydollar server.
          def acknowledge
            # Print out 'OK' to notify Paydollar that we have received the
            # payment result
            "OK"
          end

          #################################################################
          # The following fields are received ONLY for MPS Enabled accounts

          # MPS Transaction Amount
          # @return [String] MPS transaction amount
          def mps_amount
            params['mpsAmt']
          end

          # MPS Transaction Currency
          # @return [String] MPS transaction currency
          def mps_currency
            params['mpsCur']
          end          

          # MPS Transaction Foreign Amount
          # @return [String] MPS transaction foreign amount
          def mps_foreign_amount
            params['mpsForeignAmt']
          end          

          # MPS Transaction Foreign Currency
          # @return [String] MPS transaction foreign currency
          def mps_foreign_currency
            params['mpsForeignCur']
          end

          # MPS Exchange Rate
          # @return [String] MPS Exchange Rate: (Foreign / Base)
          #   e.g. USD / HKD = 7.77
          def mps_exchange_rate
            params['mpsRate']
          end

          #################################################################
          # The following fields are received ONLY schedule payment transaction

          # The Master Schedule Payment Id
          # @return [String] Master schedule payment id
          def master_schedule_payment_id
            params['mSchPayId']
          end

          # The Detail Schedule Payment Id
          # @return [String] Detail schedule payment id
          def detail_schedule_payment_id
            params['dSchPayId']
          end

          #################################################################
          # The following fields are related to installments

          # Installment period in months
          # @return [String] Installment period in months
          def installment_period_in_mnths
            params['installment_period']
          end

          # The transaction amount for first installment period
          # @return [String] The transaction amount for first installment period
          def installment_first_pay_amt
            params['installment_firstPayAmt']
          end

          # The transaction amount for each installment period
          # @return [String] The transaction amount for each installment period
          def installment_each_pay_amt
            params['installment_eachPayAmt']
          end

          # The transaction amount for last installment period
          # @return [String] The transaction amount for last installment period
          def installment_last_pay_amt
            params['installment_lastPayAmt']
          end

          private
          # Generate the secure hash.
          # The secure has for a datafeed is calcuated as by hashing the
          # following parameters using SHA-1:
          # - Src
          # - Prc
          # - Success Code
          # - Merchant Reference Number
          # - PayDollar Reference Number
          # - Currency Code
          # - Amount
          # - Payer Authentication Status
          # - Secure Hash Secret
          # See "Transaction security by Secure Hash" section in Paydollar
          # documentation for all details.
          #NOTE: Applies to merchants who registered this function only.
          # @return [String] The 
          def generate_secure_hash(secret_hash)
            if secret_hash
              # add the merchant's seceret hash
              values = [ secondary_bank_host_status_code, primary_bank_host_status_code, status, 
                         item_id, paydollar_ref, currency, gross, payer_auth_status, 
                         secret_hash ].join("|")
              Digest::SHA1.hexdigest(values).upcase
            end
          end
        end
      end
    end
  end
end

