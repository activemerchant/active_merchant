require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module A1agregator
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          self.production_ips = [
            '78.108.178.206',
            '79.137.235.129',
            '95.163.96.79',
            '212.24.38.100'
          ]

          def initialize(*args)
            super
            guess_notification_type
          end

          # Simple notification request params:
          # tid
          # name
          # comment
          # partner_id
          # service_id
          # order_id
          # type
          # partner_income
          # system_income

          def complete?
            true
          end

          def transaction_id
            params['tid']
          end

          def title
            params['name']
          end

          def comment
            params['comment']
          end

          def partner_id
            params['partner_id']
          end

          def service_id
            params['service_id']
          end

          def item_id
            params['order_id']
          end

          def type
            params['type']
          end

          def partner_income
            params['partner_income']
          end

          def system_income
            params['system_income']
          end

          # Additional notification request params:
          # tid
          # name
          # comment
          # partner_id
          # service_id
          # order_id
          # type
          # cost
          # income_total
          # income
          # partner_income
          # system_income
          # command
          # phone_number
          # email
          # resultStr
          # date_created
          # version
          # check

          def inclome_total
            params['income_total']
          end

          def income
            params['income']
          end

          def partner_income
            params['partner_income']
          end

          def system_income
            params['system_income']
          end

          def command
            params['command']
          end

          def phone_number
            params['phone_number']
          end

          def payer_email
            params['email']
          end

          def result_string
            params['resultStr']
          end

          def received_at
            params['date_created']
          end

          def version
            params['version']
          end

          def security_key
            params[A1agregator.signature_parameter_name].to_s.downcase
          end

          # the money amount we received in X.2 decimal.
          alias_method :gross, :system_income

          def currency
            'RUB'
          end

          # Was this a test transaction?
          def test?
            params['test'] == '1'
          end

          def simple_notification?
            @notification_type == :simple
          end

          def additional_notification?
            @notification_type == :additional
          end

          def acknowledge(authcode = nil)
            security_key == signature
          end

        private

          def signature
            data = "#{params['tid']}\
#{params['name']}\
#{params['comment']}\
#{params['partner_id']}\
#{params['service_id']}\
#{params['order_id']}\
#{params['type']}\
#{params['partner_income']}\
#{params['system_income']}\
#{params['test']}\
#{@options[:secret]}"
            Digest::MD5.hexdigest(data)
          end

          def guess_notification_type
            @notification_type = params['version'] ? :additional : :simple
          end

        end
      end
    end
  end
end
