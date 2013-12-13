require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Doku
          class Notification < ActiveMerchant::Billing::Integrations::Notification

          self.production_ips = ['103.10.128.11', '103.10.128.14']

          def complete?
            status.present?
          end

          def item_id
            params['TRANSIDMERCHANT']
          end

          def gross
            params['AMOUNT']
          end

          def status
            case params['RESULT']
            when 'Success'
              'Completed'
            when 'Fail'
              'Failed'
            end
          end

          def currency
            'IDR'
          end

          def words
            params['WORDS']
          end

          def type
            if words && params['STOREID']
              'verify'
            elsif status
              'notify'
            end
          end

          def acknowledge(authcode = nil)
            case type
            when 'verify'
              words == @options[:credential2]
            when 'notify'
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
