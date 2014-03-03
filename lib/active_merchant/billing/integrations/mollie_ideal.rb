require File.dirname(__FILE__) + '/mollie_ideal/return.rb'
require File.dirname(__FILE__) + '/mollie_ideal/helper.rb'
require File.dirname(__FILE__) + '/mollie_ideal/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal

        MOLLIE_API_V1_URI = 'https://api.mollie.nl/v1/'.freeze

        mattr_accessor :live_issuers
        self.live_issuers = {
          'ideal' => [
            ["ABN AMRO", "ideal_ABNANL2A"],
            ["ASN Bank", "ideal_ASNBNL21"],
            ["Friesland Bank", "ideal_FRBKNL2L"],
            ["ING", "ideal_INGBNL2A"],
            ["Knab", "ideal_KNABNL2H"],
            ["Rabobank", "ideal_RABONL2U"],
            ["RegioBank", "ideal_RBRBNL21"],
            ["SNS Bank", "ideal_SNSBNL2A"],
            ["Triodos Bank", "ideal_TRIONL2U"],
            ["van Lanschot", "ideal_FVLBNL22"]
          ]
        }

        mattr_accessor :test_issuers
        self.test_issuers = {
          'ideal' => [
            ["TBM Bank", "ideal_TESTNL99"]
          ]
        }

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end

        def self.live?
          ActiveMerchant::Billing::Base.integration_mode == :production
        end

        def self.requires_redirect_param?
          true
        end

        def self.redirect_param_options(method = 'ideal')
          live? ? live_issuers[method] : test_issuers[method]
        end

        def self.retrieve_issuers(token, method = 'ideal')
          response = mollie_api_request(token, :get, "issuers")
          response['data']
            .select { |issuer| issuer['method'] == method }
            .map { |issuer| [issuer['name'], issuer['id']] }
        end

        def self.create_payment(token, params)
          MollieIdeal.mollie_api_request(token, :post, 'payments', params)
        end

        def self.check_payment_status(token, payment_id)
          MollieIdeal.mollie_api_request(token, :get, "payments/#{payment_id}")
        end

        def self.mollie_api_request(token, http_method, resource, params = nil)
          uri = URI.parse(MOLLIE_API_V1_URI + resource)

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE

          request = case http_method
            when :get;  Net::HTTP::Get.new(uri.path)
            when :post; Net::HTTP::Post.new(uri.path)
            else raise ActiveMerchant::Billing::Error, "Request method #{http_method} not supported"
          end

          request["Authorization"] = "Bearer #{token}"
          request.body = JSON.dump(params) unless params.nil?

          response = http.request(request)
          case response
          when Net::HTTPSuccess
            puts response.body
            JSON.parse(response.body)
          when Net::HTTPClientError
            message = JSON.parse(response.body).fetch('error', {}).fetch('message', 'Unknown Mollie error')
            raise ActiveMerchant::Billing::Error, "Mollie returned error #{response.code}: #{message}"
          else
            raise ActiveMerchant::Billing::Error, "Mollie returned unexpected response status #{response.code}."
          end
        end
      end
    end
  end
end
