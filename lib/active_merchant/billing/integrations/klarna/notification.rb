require 'net/http'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def initialize(post, options = {})
            super
            verify_request
          end

          def complete?
            status == 'Complete'
          end

          def item_id
            params["reservation"]
          end

          def transaction_id
            params["reference"]
          end

          def received_at
            params["completed_at"]
          end

          def payer_email
            params["billing_address"]["email"]
          end

          def receiver_email
            params["shipping_address"]["email"]
          end

          def currency
            params["purchase_currency"]
          end

          def gross
            Float(gross_cents) / 100
          end

          def gross_cents
            Integer(params["cart"]["total_price_including_tax"])
          end

          def test?
            false
          end

          def status
            case params['status']
            when 'checkout_complete'
              'Complete'
            else
              params['status']
            end
          end

          def acknowledge(authcode = nil)
            true
          end

          private

          def parse(post)
            @raw = post.to_s
            @params = JSON.parse(post)
          end

          def verify_request
            shared_secret = @options[:credential2]
            Verifier.new(@options[:authorization_header], @raw, shared_secret).verify
          end

          class VerificationError < StandardError; end

          class Verifier
            attr_reader :header, :payload, :digest, :shared_secret
            def initialize(header, payload, shared_secret)
              @header, @payload, @shared_secret = header, payload, shared_secret

              @digest = extract_digest
            end

            def verify
              raise VerificationError, "Klarna notification failed signature verification" unless digest_matches?
            end

            private

            def extract_digest
              match = header.match(/^Klarna (?<digest>.+)$/)
              match && match[:digest]
            end

            def digest_matches?
              Digest::SHA256.base64digest(payload + shared_secret) == digest
            end
          end
        end
      end
    end
  end
end
