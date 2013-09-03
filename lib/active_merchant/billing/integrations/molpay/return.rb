module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay
        class Return < ActiveMerchant::Billing::Integrations::Return
          include ActiveMerchant::PostsData

					#order id
					def order
            params["orderid"]
          end
					
					#approval code
					def appcode
            params["appcode"]
          end
					
					#transaction id
					def transaction
            params["tranID"]
          end
					
					#account / merchant id
          def account
            params["domain"]
          end
					
					#return status
          def status
            params["status"]
          end
					
					#amount buying
          def amount
            params["amount"]
          end
					
					#currency					
          def currency
            params["currency"]
          end
					
					#day payment were done
					def paydate
            params["paydate"]
          end
					
					#authorization code / skey
          def auth_code
            params["skey"]
          end
					
					#channel buyer used
					def channel
            params["channel"]
          end
					
					#check authorization code prevent authorize callback
          def acknowledge(authcode)
						require 'digest/md5'
						
						key1 = Digest::MD5.hexdigest( self.transaction + self.order + self.status + self.account + self.amount + self.currency )
						key2 = self.paydate + self.account + key1 + self.appcode + authcode
						
						Digest::MD5.hexdigest( key2 )
          end
					
					#if return status were success
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
