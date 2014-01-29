require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module GoCoin
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == 'ready_to_ship'
          end

          def status
            params['payload']['status']
          end

          # GoCoin Event ID
          def transaction_id
            params['id']
          end

          # GoCoin Invoice ID
          def item_id
            params['payload']['id']
          end

          # Time GoCoin server generated callback
          def received_at
            Time.parse(params['payload']['server_time']) rescue return nil
          end

          # Base currency invoice was created with
          def currency
            params['payload']['base_price_currency']
          end

          # Crypto currency invoice was actually paid in
          def crypto_currency
            params['payload']['price_currency']
          end

          # Gross amount of the invoice in base currency
          def gross
            params['payload']['base_price'].to_f
          end

          # Gross amount charged to customer in crypto-currency
          def crypto_gross
            BigDecimal.new(params['payload']['price'], 8)
          end

          # Hits the GoCoin API to get the invoice and compare the data
          def acknowledge(access_token = nil)
            uri = URI.parse("#{ActiveMerchant::Billing::Integrations::GoCoin.read_invoice_url_prefix}/#{item_id}")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Get.new(uri.path)
            request.add_field("Authorization", "Bearer #{access_token}")
            response = http.request(request)
            retrieved_params = JSON.parse(response.body.to_s)

            # Check that params in callback data and API GET Invoice data are the same (except server_time)
            params['payload'].tap { |h| h.delete 'server_time' } == retrieved_params.tap { |h| h.delete 'server_time' }
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
