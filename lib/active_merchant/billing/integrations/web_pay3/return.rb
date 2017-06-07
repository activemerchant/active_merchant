module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WebPay3
        class Return < ActiveMerchant::Billing::Integrations::Return

          # return url string for canceled payment: http://0.0.0.0:4000/return_url?language=en&order_number=2
          # return url string for approved transaction:
          # http://0.0.0.0:4000/return_url?
          # approval_code=847983&
          # authentication=&
          # cc_type=visa&
          # currency=USD&
          # custom_params=&
          # digest=0659c5d1e62219a51b1c231c3966eb35fc220a4c&
          # enrollment=N&
          # language=en&
          # order_number=2&
          # response_code=0000

          def initialize(post, options)
            super
          end

          def order_number
            params['order_number'].to_s
          end

          def returned_digest
            params['digest'].to_s
          end

          def calculated_digest
            Digest::SHA1.hexdigest("#{@options[:key]}#{order_number}")
          end

          # payment is processed if returned digest is same as calculated
          def success?
            params['digest'] and (calculated_digest == returned_digest)
          end

          # payment is canceled if there is no returned digest
          def cancelled?
            params['order_number'] and params['digest'].nil?
          end
        end
      end
    end
  end
end
