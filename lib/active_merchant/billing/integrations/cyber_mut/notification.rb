require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CyberMut
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            if test?
              status == 'payetest'
            else
              status == 'paiement'
            end
          end

          def item_id
            params['reference']
          end

          def transaction_id
            params['reference']
          end

          # When was this payment received by the client.
          def received_at
            Time.parse(params['date'].gsub('_a_', ' ')) if params['date']
          end

          def payer_email
            params['mail']
          end

          def receiver_email
            params['mail']
          end

          # the money amount we received in X.2 decimal with devise
          # Needs to have dot instead of comma to comply to `to_f`.
          def gross
            params['montant'][0..-4].gsub(",", ".")
          end

          # What currency have we been dealing with
          def currency
            params['montant'][-3..-1]
          end

          # Was this a test transaction?
          def test?
            mode = ActiveMerchant::Billing::Base.integration_mode
            mode == :test
          end

          # Status of transaction. List of possible values:
          #
          # * payetest :: Payment accepted on test environment only
          # * paiement :: Payment accepted on prod environment only
          # * Annulation :: Payment refused
          def status
            params['code-retour']
          end

          # Acknowledge the transaction to CyberMut. This method has to be called after a new
          # apc arrives. CyberMut will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = CyberMutNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge
            payload = raw

            uri = URI.parse(CyberMut.service_url)

            request = Net::HTTP::Post.new(uri.path)

            request['Content-Length'] = "#{payload.size}"
            request['User-Agent'] = "Active Merchant -- http://home.leetsoft.com/am"
            request['Content-Type'] = "application/x-www-form-urlencoded"

            http = Net::HTTP.new(uri.host, uri.port)
            http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
            http.use_ssl        = true

            response = http.request(request, payload)

            # Replace with the appropriate codes
            raise StandardError.new("Faulty CyberMut result: #{response.body}") unless ["AUTHORISED", "DECLINED"].include?(response.body)
            response.body == "AUTHORISED"
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten.compact
              params[key] = CGI.unescape(value) if key && value
            end
          end
        end
      end
    end
  end
end
