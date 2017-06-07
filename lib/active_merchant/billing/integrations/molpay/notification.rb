require 'net/http'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include ActiveMerchant::PostsData
	  
          #Initialize
          def initialize(data, options)
            if options[:credential2].nil?
              raise ArgumentError, "You need to provide the md5 secret as the option :credential2 to verify that the notification originated from Molpay"
            end
            super
          end
	
          #Order id
          def order
            params["orderid"]
          end
					
          #Approval code
          def appcode
            params["appcode"]
          end
					
          #Transaction id
          def transaction
            params["tranID"]
          end
					
          #Account / merchant id
          def account
            params["domain"]
          end
					
          #Return status
          def status
            params["status"]
          end
					
          #Amount buying
          def amount
            params["amount"]
          end
					
          #Currency used (mostly MYR)			
          def currency
            params["currency"]
          end
					
          #Day payment were done
          def paydate
            params["paydate"]
          end
					
          #Authorization code / skey
          def auth_code
            params["skey"]
          end
					
          #Channel buyer used
          def channel
            params["channel"]
          end
    
          #MOLPay vcode
          def secret
            @options[:credential2]
          end
					
          #Check authorization code prevent authorize callback
          def acknowledge()						
            key1 = Digest::MD5.hexdigest( self.transaction + self.order + self.status + self.account + self.amount + self.currency )
            key2 = self.paydate + self.account + key1 + self.appcode + self.secret
	 			
            Digest::MD5.hexdigest( key2 )
          end
					
          #If return status were success
          def success?
            if( self.status == '00' ) 
              true
            else 
              false
            end
          end
        end
      end
    end
  end
end	
