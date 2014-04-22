require 'net/http'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PagSeguro
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(post, options = {})
            notify_code = parse_http_query(post)["notificationCode"]
            email = options[:credential1]
            token = options[:credential2]

            uri = URI.join(PagSeguro.notification_url, notify_code)
            parse_xml(web_get(uri, email: email, token: token))
          end

          def complete?
            status == "Completed"
          end

          def item_id
            params["transaction"]["reference"]
          end

          def transaction_id
            params["transaction"]["code"]
          end

          def received_at
            params["transaction"]["date"]
          end

          def payer_email
            params["sender"]["email"]
          end

          def gross
            params["transaction"]["grossAmount"]
          end

          def currency
            "BRL"
          end

          def payment_method_type
            params["transaction"]["paymentMethod"]["type"]
          end

          def payment_method_code
            params["transaction"]["paymentMethod"]["code"]
          end

          def status
            case params["transaction"]["status"]
            when "1", "2"
              "Pending"
            when "3"
              "Completed"
            when "4"
              "Available"
            when "5"
              "Dispute"
            when "6"
              "Reversed"
            when "7"
              "Failed"
            end
          end

          # There's no acknowledge for PagSeguro
          def acknowledge
            true
          end

          private

          def web_get(uri, params)
            uri.query = URI.encode_www_form(params)

            response = Net::HTTP.get_response(uri)
            response.body
          end

          # Take the posted data and move the relevant data into a hash
          def parse_xml(post)
            @params = Hash.from_xml(post)
          end

          def parse_http_query(post)
            @raw = post
            params = {}
            for line in post.split('&')
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              params[key] = value
            end
            params
          end
        end
      end
    end
  end
end
