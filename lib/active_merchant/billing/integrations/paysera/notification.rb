require 'net/http'
require 'open-uri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paysera
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          PAYMENT_SUCCESSFUL = '1'

          PAYMENT_STATUS = {
              '0' => 'Payment failed',
              '1' => 'Payment successful',
              '2' => 'Payment accepted but stalled',
              '3' => 'New payer information received',
          }

          def initialize(data, options)
            if options[:credential2].nil?
              raise ArgumentError, 'You need to provide a project password'
            end

            super
          end

          def complete?
            params['status'] == PAYMENT_SUCCESSFUL
          end

          def item_id
            params['orderid']
          end

          def transaction_id
            params['requestid']
          end

          def payer_email
            params['p_email']
          end

          def security_key
            @options[:credential2]
          end

          # the money amount we received in X.2 decimal.
          def gross
            gross_cents / 100
          end

          def gross_cents
            params['payamount'].to_i
          end

          def currency
            params['paycurrency']
          end

          # Was this a test transaction?
          def test?
            params['test'] == '1'
          end

          def status
            PAYMENT_STATUS[params['status']]
          end

          # Acknowledge the transaction to Paysera.
          def acknowledge(authcode = nil)
            signature_v1_valid? and signature_v2_valid?
          end

          def signature_v1_valid?
            generate_signature_v1(raw['data'], security_key) == raw['ss1']
          end

          def signature_v2_valid?
            validate_signature_v2(raw['ss2'], raw['data'])
          end

          private
          # Take the posted data and move the relevant data into a hash
          def parse(post)
            if post.is_a?(Hash)
              @raw = post
            else
              @raw = parse_and_return post
            end

            @params = parse_and_return Base64.urlsafe_decode64(@raw['data'])
          end

          # A non-mutable version of parse
          def parse_and_return(post)
            params = {}
            unprocessed = post.to_s

            for line in unprocessed.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value.to_s) if key.present?
            end
            params
          end
        end
      end
    end
  end
end
