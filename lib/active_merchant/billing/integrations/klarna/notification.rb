require 'net/http'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Klarna
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def initialize(post, options = {})
            super
            @shared_secret = @options[:credential2]
          end

          def complete?
            status == 'Completed'
          end

          def item_id
            order
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
            params["purchase_currency"].upcase
          end

          def gross
            amount = Float(gross_cents) / 100
            sprintf("%.2f", amount)
          end

          def gross_cents
            params["cart"]["total_price_including_tax"]
          end

          def status
            case params['status']
            when 'checkout_complete'
              'Completed'
            else
              params['status']
            end
          end

          def acknowledge(authcode = nil)
            Verifier.new(@options[:authorization_header], @raw, @shared_secret).verify
          end

          private

          def order
            query = Rack::Utils.parse_nested_query(@options[:query_string])
            query["order"]
          end

          def parse(post)
            @raw = post.to_s
            @params = JSON.parse(post)
          end

          class Verifier
            attr_reader :header, :payload, :digest, :shared_secret
            def initialize(header, payload, shared_secret)
              @header, @payload, @shared_secret = header, payload, shared_secret

              @digest = extract_digest
            end

            def verify
              digest_matches?
            end

            private

            def extract_digest
              match = header.match(/^Klarna (?<digest>.+)$/)
              match && match[:digest]
            end

            def digest_matches?
              Klarna.digest(payload, shared_secret) == digest
            end
          end
        end
      end
    end
  end
end
