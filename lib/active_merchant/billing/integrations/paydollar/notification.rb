require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar

        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def complete?
            status == 'Completed'
          end

          def item_id
            @params['Ref']
          end

          def currency
            CURRENCY_MAP.key(@params['Cur'])
          end

          def gross
            @params['Amt']
          end

          def transaction_id
            @params['PayRef']
          end

          def status
            case @params['successcode']
              when '0' then 'Completed'
              else 'Failed'
            end
          end

          def acknowledge(authcode = nil)
            # paydollar supports multiple signature keys, therefore we need to check if any
            # of their signatures match ours
            hash = @params['secureHash']
            if !hash
              return false
            end
            hash.split(',').include? generate_secure_hash
          end

          private
          def generate_secure_hash
            fields = [@params['src'],
                      @params['prc'],
                      @params['successcode'],
                      @params['Ref'],
                      @params['PayRef'],
                      @params['Cur'],
                      @params['Amt'],
                      @params['payerAuth']]
            Paydollar.sign(fields, @options[:credential2])
          end

        end
      end
    end
  end
end
