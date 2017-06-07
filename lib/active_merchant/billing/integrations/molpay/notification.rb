module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Molpay
      # Example
      # ========
      #
      # notification = Molpay::Notification.new(request.raw_post, options = {:credential2 => "SECRET_KEY"})
      #
      # @order = Order.find(notification.item_id)
      #
      # begin
      #   if notification.acknowledge
      #     @order.status = 'success'
      #     redirect_to @order
      #   else
      #     @order.status = 'failed'
      #     render :text => "Failed Transaction"
      #   end
      # ensure
      #   @order.save
      # end

        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData

          def complete?
            status == 'Completed'
          end

          def item_id
            params['orderid']
          end

          def transaction_id
            params['tranID']
          end

          def account
            params["domain"]
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          def currency
            params['currency']
          end

          def channel
            params['channel']
          end

          # When was this payment received by the client.
          def received_at
            params['paydate']
          end

          def auth_code
            params['appcode']
          end

          def error_code  
            params['error_code']
          end

          def error_desc
            params['error_desc']
          end

          def security_key
            params['skey']
          end

          def test?
            gross.blank? && auth_code.blank? && error_code.blank? && error_desc.blank? && security_key.blank?
          end

          def status
            params['status'] == '00' ? 'Completed' : 'Failed' 
          end

          # Acknowledge the transaction to Molpay. This method has to be called after a new
          # apc arrives. Molpay will verify that all the information we received are correct
          #
          # Example:
          #
          #   def ipn
          #     notify = MolpayNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(authcode = nil)

            payload =  raw + '&treq=1'

            response = ssl_post(Molpay.acknowledge_url, payload,
              'Content-Length' => "#{payload.size}",
              'User-Agent'     => "Active Merchant -- http://activemerchant.org"
            )

            status == 'Completed' && security_key == generate_signature
            
          end

          protected

          def generate_signature
            Digest::MD5.hexdigest("#{gross}#{account}#{item_id}#{@options[:credential2]}")
          end

          
        end
      end
    end
  end
end
