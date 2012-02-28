require 'net/http'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      
      # # Example:
      # parser = AuthorizeNetSim::Notification.new(request.raw_post)
      # passed = parser.complete?
      # 
      # order = Order.find_by_order_number(parser.invoice_num)
      # 
      # unless order
      #   @message = 'Error--unable to find your transaction! Please contact us directly.'
      #   return render :partial => 'authorize_net_sim_payment_response'
      # end
      #       
      # if order.total != parser.gross.to_f
      #   logger.error "Authorize.Net sim said they paid for #{parser.gross} and it should have been #{order.total}!"
      #   passed = false
      # end
      # 
      # # Theoretically, Authorize.net will *never* pass us the same transaction
      # # ID twice, but we can double check that... by using
      # # parser.transaction_id, and checking against previous orders' transaction
      # # id's (which you can save when the order is completed)....      
      # unless parser.acknowledge MD5_HASH_SET_IN_AUTHORIZE_NET, AUTHORIZE_LOGIN
      #  passed = false
      #  logger.error "ALERT POSSIBLE FRAUD ATTEMPT either that or you haven't setup your md5 hash setting right in #{__FILE__} 
      #    because a transaction came back from Authorize.Net with the wrong hash value--rejecting!"
      # end
      # 
      # unless parser.cavv_matches? and parser.avs_code_matches?
      #   logger.error 'Warning--non matching CC!' + params.inspect
      #   # Could fail them here, as well (recommended)...
      # end
      # 
      # if passed
      #  # Set up your session, and render something that will redirect them to
      #  # your site, most likely.
      # else
      #  # Render failure or redirect them to your site where you will render failure
      # end
      
      module AuthorizeNetSim
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def unescape(val) #:nodoc:
            if val
              CGI::unescape val
            else
              val
            end
          end

          # Passes a hash of the address the user entered in at Authorize.Net
          def billing_address
            all = {}
            [:fax, :city, :company, :last_name, :country, :zip, :first_name, :address, :email, :state].each do |key_out|
              all[key_out] = unescape params['x_' + key_out.to_s]
            end
            all
          end

          def customer_id
            unescape params['x_cust_id']
          end

          def auth_code
            unescape params['x_auth_code']
          end

          def po_num
           unescape params['x_po_num']
          end

          def ship_to_address
           all = {}
            [:city, :last_name, :first_name, :country, :zip, :address].each do |key_out|
              all[key_out] = unescape params['x_ship_to_' + key_out.to_s]
            end
            all
          end

          # Tax amount we sent them.
          def tax
            unescape params['x_tax']
          end
          
          # Transaction type (probably going to be auth_capture, since that's
          # all we set it as).
          def transaction_type
            unescape params['x_type'] 
          end
          
          # Payment method used--almost always CC (for credit card).
          def method
            unescape params['x_method']
          end
          
          # Ff our payment method is available. Almost always "true".
          def method_available
            params['x_method_available']
          end
          
          # Invoice num we passed in as invoice_num to them.
          def invoice_num
            item_id
          end
          
          # If you pass any values to authorize that aren't its expected, it
          # will pass them back to you verbatim, returned by this method.
          # custom values:
          def all_custom_values_passed_in_and_now_passed_back_to_us
            all = {}
            params.each do |key, value|
              if key[0..1] != 'x_'
                all[key] = unescape value
              end
            end
            all
          end
          
          def duty
            unescape params['x_duty']
          end
          
          # Shipping we sent them.
          def freight
            unescape params['x_freight']
          end
          alias_method :shipping, :freight
                    
          def description
            unescape params['x_description']
          end
          
          # Returns the response code as a symbol.
          # {'1' => :approved, '2' => :declined, '3' => :error, '4' => :held_for_review}
          def response_code_as_ruby_symbol
            map = {'1' => :approved, '2' => :declined, '3' => :error, '4' => :held_for_review}
            map[params['x_response_code']]
          end
          
          def response_reason_text
            unescape params['x_response_reason_text']
          end
          
          # The response reason text's numeric id [equivalent--just a number]
          def response_reason_code
            unescape params['x_response_reason_code']
          end
          
          # 'used internally by their gateway'
          def response_subcode
            params['x_response_subcode']
          end
          
          # They pass back a tax_exempt value.
          def tax_exempt
            params['x_tax_exempt']
          end
            
          # avs [address verification] code
          # A = Address (Street) 
          # matches, ZIP does not 
          # B = Address information 
          # not provided for AVS 
          # check 
          # E = AVS error 
          # G = Non-U.S. Card Issuing
          # Bank 
          # N = No Match on Address 
          # (Street) or ZIP 
          # P = AVS not applicable for
          # this transaction 
          # R = Retry – System 
          # unavailable or timed out 
          # S = Service not supported
          # by issuer 
          # U = Address information is
          # unavailable 
          # W = Nine digit ZIP 
          # matches, Address (Street)
          # does not 
          # X = Address (Street) and 
          # nine digit ZIP match 
          # Y = Address (Street) and 
          # five digit ZIP match 
          # Z = Five digit ZIP matches
          # Address (Street) does not
          def avs_code
            params['x_avs_code']
          end
          
          # Returns true if their address completely matched [Y or X, P from
          # #avs_code, which mean 'add+zip match', 'address + 9-zip match', and
          # not applicable, respectively].
          def avs_code_matches?
            return ['Y', 'X', 'P'].include? params['x_avs_code']
          end
          
          # cvv2 response
          # M = Match 
          # N = No Match 
          # P = Not Processed 
          # S = Should have been 
          # present 
          # U = Issuer unable to 
          # process request 
          def cvv2_resp_code
            params['x_cvv2_resp_code']
          end
          
          # check if #cvv2_resp_code == 'm' for Match.  otherwise false
          def cvv2_resp_code_matches?
            return ['M'].include? cvv2_resp_code
          end

          # cavv_response--'cardholder authentication verification response code'--most likely not use for SIM
          # Blank or not present  =  
          # CAVV not validated 
          # 0 = CAVV not validated 
          # because erroneous data 
          # was submitted 
          # 1 = CAVV failed validation
          # 2 = CAVV passed 
          # validation 
          # 3 = CAVV validation could
          # not be performed; issuer 
          # attempt incomplete 
          # 4 = CAVV validation could
          # not be performed; issuer 
          # system error 
          # 5 = Reserved for future 
          # use 
          # 6 = Reserved for future 
          # use 
          # 7 = CAVV attempt – failed
          # validation – issuer 
          # available (U.S.-issued 
          # card/non-U.S acquirer) 
          # 8 = CAVV attempt – 
          # passed validation – issuer
          # available (U.S.-issued 
          # card/non-U.S. acquirer) 
          # 9 = CAVV attempt – failed
          # validation – issuer 
          def cavv_response
            params['x_cavv_response']
          end
          
          # Check if #cavv_response == '', '2', '8' one of those [non failing]
          # [blank means no validated, 2 is passed, 8 is passed issuer
          # available]
          def cavv_matches?
            ['','2','8'].include? cavv_response
          end
           
          # Payment is complete -- returns true if x_response_code == '1'
          def complete?
            params["x_response_code"] == '1'
          end 

          # Alias for invoice number--this is the only id they pass back to us
          # that we passed to them, except customer id is also passed back.
          def item_id
            unescape params['x_invoice_num']
          end

          # They return this number to us [it's unique to Authorize.net].
          def transaction_id
            params['x_trans_id']
          end

          # When was this payment was received by the client. --unimplemented --
          # always returns nil
          def received_at
            nil
          end

          # End-user's email
          def payer_email
            unescape params['x_email']
          end

          # They don't pass merchant email back to us -- unimplemented -- always
          # returns nil
          def receiver_email
            nil
          end 

          # md5 hash used internally
          def security_key
            params['x_MD5_Hash']
          end

          # The money amount we received in X.2 decimal. Returns a string
          def gross
            unescape params['x_amount']
          end

          # Was this a test transaction?
          def test?
            params['x_test_request'] == 'true'
          end

          # #method_available alias
          def status
            complete?
          end

          # Called to request back and check if it was a valid request.
          # Authorize.net passes us back a hash that includes a hash of our
          # 'unique' MD5 value that we set within their system.
          #
          # Example: 
          # acknowledge('my secret md5 hash that I set within Authorize.Net', 'authorize_login')
          #
          # Note this is somewhat unsafe unless you actually set that md5 hash
          # to something (defaults to '' in their system).
          def acknowledge(md5_hash_set_in_authorize_net, authorize_net_login_name)
            Digest::MD5.hexdigest(md5_hash_set_in_authorize_net + authorize_net_login_name + params['x_trans_id'] + gross) == params['x_MD5_Hash'].downcase
          end
          
         private

          # Take the posted data and move the relevant data into a hash.
          def parse(post)
            @raw = post
            post.split('&').each do |line|
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              params[key] = value
            end
          end
          
        end
      end
    end
  end
end
