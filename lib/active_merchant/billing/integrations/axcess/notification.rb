require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Axcess
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData
          
          def complete?
            params['PROCESSING.RESULT'] == 'ACK'
          end

          def cancel?
            params['FRONTEND.REQUEST.CANCELLED']=='true'
          end

          def item_id
            params['IDENTIFICATION.TRANSACTIONID']
          end

          def transaction_id
            params['IDENTIFICATION.UNIQUEID']
          end

          # When was this payment received by the client.
          def received_at
            params['PROCESSING.TIMESTAMP']
          end

          def payer_email
            params['CONTACT.EMAIL']
          end

          def security_key
            params['']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['CLEARING.AMOUNT']
          end

          # Was this a test transaction?
          def test?
            params['TRANSACTION.MODE'] != 'LIVE'
          end

          def status
            params['PROCESSING.STATUS']
          end

          def message
            params['PROCESSING.RETURN']
          end

          # Acknowledge the transaction to Axcess. This method has to be called after a new
          # apc arrives. Axcess will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = AxcessNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(secret)
            require 'digest/md5'
            Digest::MD5.hexdigest("#{params['PAYMENT.CODE']}|#{params['IDENTIFICATION.TRANSACTIONID']}|#{params['IDENTIFICATION.UNIQUEID']}|#{params['PROCESSING.RETURN.CODE']}|#{params['CLEARING.AMOUNT']}|#{params['CLEARING.CURRENCY']}|#{params['PROCESSING.RISK_SCORE']}|#{params['TRANSACTION.MODE']}|#{secret}") == params['HASH']
          end
 private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')    
              key, value = *line.scan( %r{^([A-Za-z0-9_.]+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value)
            end
          end
        end
      end
    end
  end
end
