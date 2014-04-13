require 'net/http'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PagSeguro
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(post, options = {})
            super

            notify_code = post["notificationCode"]
            email = options[:credential1]
            token = options[:credential2]

            url = "#{PagSeguro.notification_url}#{notify_code}"
            parse(web_get(url, email: email, token: token))
          end

          def complete?
            params["transaction"]["type"] == "1"
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
            # PagSeguro is exclusive to Brazil's currency
            "BRL"
          end

          def status
            #
            # This needs revision. We may not need all the statuses
            #
            case params["transaction"]["status"]
            when "1"
              "Waiting payment"
            when "2"
              "Pending"
            when "3"
              "Completed"
            when "4"
              "Available"
            when "5"
              "Dispute"
            when "6"
              "Failed"
            when "7"
              "Cancelled"
            end
          end

          # There's no acknowledge for PagSeguro
          def acknowledge
            true
          end

          private

          def web_get(url, params)
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Get.new(uri.request_uri)
            request.content_type = "application/x-www-form-urlencoded"
            request.set_form_data(params)

            response = http.request(request)
            response.body
          end

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post
            @params = Hash.from_xml(post)
          end
        end
      end
    end
  end
end
