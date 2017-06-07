module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module RedDotPayment
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def initialize(post, options = {})
            super
            @options = options
            raise StandardError.new("No credential3 supplied in options") unless options[:credential3].present?
            raise StandardError.new("Faulty post: No order_number in params") unless params['order_number'].present?
          end

          def complete?
            true
          end

          def item_id
            params['order_number']
          end

          def transaction_id
            params['transaction_id']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          def status
            params['result']
          end

          def currency
            params['currency_code']
          end

          # Was this a test transaction?
          def test?
            false
          end

          # Not suppported
          def received_at
          end

          def payer_email
          end

          def receiver_email
          end

          def security_key
            params['signature']
          end

          def acknowledge(authcode = nil)
            params['signature'].present? && params['signature'] == response_signature
          end

          private

          def response_signature
            checksum_keys = params.keys.sort.select { |param| param != 'signature' }

            checksum = checksum_keys.map do |key|
              "#{key}=#{params[key]}"
            end << "secret_key=#{@options[:credential3]}"

            Digest::MD5.hexdigest(checksum.join("&"))
          end
        end
      end
    end
  end
end
