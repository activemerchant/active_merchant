require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Veritrans
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData

          attr_reader :acknowledge_response
          def initialize post, options = {}
            super
            @acknowledge_response = {}
            early_acknowledge 
          end
          
          def complete?
            %w{success failure pending}.include?status 
          end

          def item_id
            params['TOKEN_MERCHANT'] || ""
          end

          def transaction_id
            params['orderId']
          end

          def currency
            'IDR'
          end
          # When was this payment received by the client.
          def received_at
            acknowledge_response['received_at']
          end

          def payer_email
            receiver_email
          end

          def receiver_email
            params['email'] || ""
          end

          def security_key
            params['vResultCode'] || ""
          end

          # the money amount we received in X.2 decimal.
          def gross
            '%.2f' % (acknowledge_response['total_amount'] || 0)
          end

          # Was this a test transaction?
          def test?
            acknowledge_response['merchant_id'] =~ /^T/ ? true : false
          end

          def status
            params['mStatus'].downcase || ""
          end

          def process_result
            params['mStatus'] || ''
          end

          def acknowledge
            raise @early_acknowledge_error unless @early_acknowledge_error.nil?
            valid_status = %{authorize settlement pending reversal cancel deny verify signature}
            raise StandardError.new("Faulty Veritrans result : #{ @acknowledge_body }") unless %w{verified unverified}.include?(acknowledge_response['acknowledge'])
            acknowledge_response['acknowledge'] == 'verified'
          end

          private
          def build_autorization
            'Basic ' + ["#{@options[:merchant_id]}:#{@options[:merchant_hash_key]}"].pack('m').delete("\r\n")
          end
          def early_acknowledge
            begin
              response = ssl_post Veritrans.acknowledge_url , {:notification => params}.to_query, {'Authorization' => build_autorization}
              @acknowledge_body = response
              @acknowledge_response = JSON.parse(response)
            rescue Exception => e
              @early_acknowledge_error = e
            end
          end
          def parse(post)
            _params =JSON.parse(post)
            _params.each{|key, value| params[key] = value}
          end

        end
      end
    end
  end
end
