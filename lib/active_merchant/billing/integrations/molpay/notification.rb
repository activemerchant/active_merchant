require 'net/http'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include ActiveMerchant::PostsData
	  
	  #initialize
	  def initialize(data, options)
            if options[:credential2].nil?
              raise ArgumentError, "You need to provide the md5 secret as the option :credential2 to verify that the notification originated from Molpay"
            end
            super
          end
	
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
    
    	  def secret
            @options[:credential2]
          end
					
	  #check authorization code prevent authorize callback
          def acknowledge()
	    require 'digest/md5'
						
	    key1 = Digest::MD5.hexdigest( self.transaction + self.order + self.status + self.account + self.amount + self.currency )
	    key2 = self.paydate + self.account + key1 + self.appcode + self.secret
	 			
	    Digest::MD5.hexdigest( key2 )
          end
					
	  #if return status were success
          def success?
            if( self.status == '00' ) true
	    else false
	    end
          end
        end
      end
    end
  end
end	
