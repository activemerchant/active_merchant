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
            ActiveMerchant::Billing::Base.mode == :test
          end

          # Status of transaction. List of possible values:
          #
          # * payetest :: Payment accepted on test environment only
          # * paiement :: Payment accepted on prod environment only
          # * Annulation :: Payment refused
          def status
            params['code-retour']
          end

          def acknowledge
            true
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
