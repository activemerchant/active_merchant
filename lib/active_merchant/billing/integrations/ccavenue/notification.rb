module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ccavenue
		class Notification < ActiveMerchant::Billing::Integrations::Notification
			RESPONSE_PARAMS = ['Merchant_Id','Order_Id','Checksum','Amount','AuthDesc']
			
			def initialize(post, account,  options = {})
				 
				#super(post, options)
				@merchant_id = account
				@workingKey  = options[:workingKey]
			end
			
			def valid?	
				verifychecksum(
					 @merchant_id,
					 self.Order_Id,
					 self.Amount,
					 self.AuthDesc,
					 self.CheckSum,
					 @workingKey
				)
			end
			
			def complete?
				'Y' == self.AuthDesc
				true == valid
				message = message_from(AuthDesc)
			end
			
			def pending? 
				'B' == self.AuthDesc
				true == valid
				message = message_from(AuthDesc)				
			end
			
			def decline?
				'N' == self.AuthDesc
				true == valid
				message = message_from(AuthDesc)
			end
			
			def cancel?
				false == valid
				message = message_from(AuthDesc)
			end
			
			def Order_Id
				params['Order_Id']
			end	

			def Checksum
				params['Checksum']
			end

			# the money amount we received in X.2 decimal.
			def Amount
				params['Amount']
			end

			def AuthDesc
				params['AuthDesc']
			end
			
			private

			def verify_checksum(checksum, *args)
				require 'zlib'
				Zlib.adler32(args.join('|'), 1).to_s.eql?(checksum)
			end
				
				
			def AuthDesc
				case params['AuthDesc']
					when 'Y'
						puts 'Thank you for shopping with us. Your credit card has been charged and your transaction is successful. We will be shipping your order to you soon.';
					when 'B'
						puts 'Thank you for shopping with us.We will keep you posted regarding the status of your order through e-mail.';
					when 'N'
						puts 'Thank you for shopping with us.However,the transaction has been declined by CCAvenue.';
					else
						puts 'Security Error. Illegal access detected';
				end
			end 
			
				# Take the posted data and move the relevant data into a hash
			def parse(post)	
				 
				super
					values = params['responseparams'].to_s.split('|')					
					response_params = values.size == 3 ? ['Merchant_id', 'Amount', 'message'] : RESPONSE_PARAMS					
					response_params.each_with_index do |name, index|
					params[name] = values[index]
				end
				params
			end
		end
      end
    end
  end
end
