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
            time = params['time']
            # If time only contains 12 integers then it's pre v5 format
            time = "20#{params['time']}" if /[0-9]{12}/.match(params['time'])
            Time.parse(time)
          end

          def gross
            "%.2f" % (gross_cents / 100.0)
          end

          def gross_cents
            params['amount'].to_i
          end

          def status
            params['qpstat']
          end

          def currency
            params['currency']
          end

          # Provide access to raw fields from quickpay
          %w(msgtype ordernumber state chstat chstatmsg qpstat qpstatmsg merchant merchantemail cardtype cardnumber splitpayment fraudprobability fraudremarks fraudreport fee).each do |attr|
            define_method(attr) do
              params[attr]
            end
          end

          MD5_CHECK_FIELDS = [
            :msgtype, :ordernumber, :amount, :currency, :time, :state,
            :qpstat, :qpstatmsg, :chstat, :chstatmsg, :merchant, :merchantemail,
            :transaction, :cardtype, :cardnumber, :splitpayment, :fraudprobability,
            :fraudremarks, :fraudreport, :fee
          ]

          def generate_md5string
            MD5_CHECK_FIELDS.map { |key| params[key.to_s] } * "" + @options[:credential2].to_s
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
