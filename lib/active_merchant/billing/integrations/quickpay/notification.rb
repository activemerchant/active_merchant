require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Quickpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == '000'
          end 

          def item_id
            params['ordernumber']
          end

          def transaction_id
            params['transaction']
          end

          def received_at
            DateTime.strptime(params['time'] + Time.now.zone, "%y%m%d%H%M%S%z").to_time
          end

          def gross
            "%.2f" % (gross_cents / 100.0)
          end

          def gross_cents
            params['amount'].to_i
          end

          def test?
            params['testmode'] == 'Yes'
          end

          def status
            params['qpstat']
          end

          def currency
            params['currency']
          end
          
          %w(msgtype ordernumber amount state chstat chstatmsg qpstat qpstatmsg merchant merchantemail cardtype).each do |attr|
            define_method(attr) do
              params[attr]
            end
          end

          MD5_CHECK_FIELDS = [
            :msgtype, :ordernumber, :amount, :currency, :time, :state,
            :chstat, :chstatmsg, :qpstat, :qpstatmsg, :merchant, :merchantemail,
            :transaction, :cardtype, :testmode
          ]

          def generate_md5string
            MD5_CHECK_FIELDS.map { |key| params[key.to_s] } * "" + @options[:md5secret]
          end
          
          def generate_md5check
            Digest::MD5.hexdigest(generate_md5string)
          end
          
          # Quickpay doesn't do acknowledgements of callback notifications
          # Instead it uses and MD5 hash of all parameters
          def acknowledge      
            generate_md5check == params['md5check']
          end
        end
      end
    end
  end
end
