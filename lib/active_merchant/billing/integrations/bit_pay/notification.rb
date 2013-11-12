require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == "Completed"
          end

          def transaction_id
            params['id']
          end

          def item_id
            JSON.parse(params['posData'])['orderId']
          rescue JSON::ParserError
          end

          def status
            case params['status']
            when 'complete'
              'Completed'
            when 'confirmed'
              'Pending'
            when 'invalid'
              'Failed'
            end
          end

          # When was this payment received by the client.
          def received_at
            params['invoiceTime'].to_i
          end

          def currency
            params['currency']
          end

          def gross
            params['price'].to_f
          end

          def acknowledge(authcode = nil)
            uri = URI.parse("#{ActiveMerchant::Billing::Integrations::BitPay.invoicing_url}/#{transaction_id}")

            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Get.new(uri.path)
            request.basic_auth @options[:credential1], ''

            response = http.request(request)

            posted_json = JSON.parse(@raw).tap { |j| j.delete('currentTime') }
            parse(response.body)
            retrieved_json = JSON.parse(@raw).tap { |j| j.delete('currentTime') }

            posted_json == retrieved_json
          rescue JSON::ParserError
          end

          private
          def parse(body)
            @raw = body
            @params = JSON.parse(@raw)
          rescue JSON::ParserError
          end
        end
      end
    end
  end
end
