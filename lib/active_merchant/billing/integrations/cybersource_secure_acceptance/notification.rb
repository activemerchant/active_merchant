require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CybersourceSecureAcceptance
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Security

          def initialize(post, options = {})
            super
            @secret_key = @options.delete(:credential3)
          end

          CARD_TYPES = {
            '001' => 'Visa',
            '002' => 'MasterCard',
            '003' => 'American Express',
            '004' => 'Discover',
            '005' => 'Diners Club',
            '006' => 'Carte Blanche',
            '007' => 'JCB',
            '014' => 'EnRoute',
            '021' => 'JAL',
            '024' => 'Maestro (UK Domestic)',
            '031' => 'Delta',
            '033' => 'Visa Electron',
            '034' => 'Dankort',
            '036' => 'Carte Bleue',
            '037' => 'Carta Si',
            '042' => 'Maestro (International)',
            '043' => 'GE Money UK card'
          }

          def complete?
            params['decision'] == 'ACCEPT'
          end

          def item_id
            reference_number
          end

          def payment_token
            params['payment_token'] || params['req_payment_token']
          end

          %w(transaction_id reason_code message).each do |attr|
            define_method(attr) do
              params[attr]
            end
          end

          %w(req_card_expiry_date req_card_number req_currency req_locale req_payment_method req_reference_number req_transaction_type).each do |attr|
            method_name = attr.gsub("req_", "")
            define_method(method_name) do
              params[attr]
            end
          end

          def authorization
            # This is equivalent to the authorization in the Cybersource gateway module.
            # reference_number = merchant_reference_code (order_id), transaction_id = RequestID, payment_token = requestToken.
            # payment_token is required for this. Use transaction_type=authorization,create_payment_token to include it in response.
            raise ArgumentError, 'payment_token is required for authorization code' if payment_token.blank?
            complete? ? [ reference_number, transaction_id, payment_token ].compact.join(";") : nil
          end

          def card_brand
            CARD_TYPES[params['req_card_type']]
          end

          def expiry_date
            Date.strptime params['req_card_expiry_date'], '%m-%Y'
          end

          # When was this payment received by the client.
          def received_at
            DateTime.strptime params['auth_time'], '%Y-%m-%dT%H%M%SZ'
          end

          def security_key
            params['signature']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['auth_amount']
          end

          def status
            params['decision']
          end

          def get_signature
            generate_signature params
          end

          def test?
            @test_mode ||= ActiveMerchant::Billing::Base.integration_mode == :test || @test
          end

          # Acknowledge the transaction to CybersourceSecureAcceptance. This method has to be called after a new
          # apc arrives. CybersourceSecureAcceptance will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = CybersourceSecureAcceptanceNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(authcode = nil)
            valid? params
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value.to_s) if key.present?
            end
          end
        end
      end
    end
  end
end
