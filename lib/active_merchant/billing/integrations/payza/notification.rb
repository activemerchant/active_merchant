module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Payza
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData

          def complete?
            status == 'Success'
          end

          def item_id
            params['ap_itemcode']
          end

          def transaction_id
            params['ap_referencenumber']
          end

          def received_at
            params['ap_transactiondate']
          end

          def receiver_email
            params['ap_merchant']
          end

          def security_key
            params['ap_securitycode']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['ap_totalamount']
          end

          def currency
            params['ap_currency']
          end

          def test?
            params['ap_test'] == '1'
          end

          def status
            params['ap_status']
          end

          def acknowledge(authcode = nil)
            payload = raw

            response = ssl_post(Payza.notification_confirmation_url, payload,
              'Content-Length' => "#{payload.size}",
              'User-Agent'     => "Active Merchant -- http://activemerchant.org"
            )

            if response == "INVALID TOKEN"
              false
            else
              parse_ipn_response(response)
              true
            end
          end

          private

          def parse_ipn_response(post)
            unescaped_post = CGI.unescape(post)
            for line in unescaped_post.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.]+)\=(.*)$} ).flatten
              params[key] = value
            end
          end
        end
      end
    end
  end
end
