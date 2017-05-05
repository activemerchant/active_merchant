require File.dirname(__FILE__) + '/mollie_ideal/return.rb'
require File.dirname(__FILE__) + '/mollie_ideal/helper.rb'
require File.dirname(__FILE__) + '/mollie_ideal/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal
        class API
          include PostsData

          attr_reader :token

          def initialize(token)
            @token = token
          end

          def get_request(resource, params = nil)
            uri = URI.parse(MOLLIE_API_V1_URI + resource)
            uri.query = params.map { |k,v| "#{CGI.escape(k)}=#{CGI.escape(v)}}"}.join('&') if params
            headers = { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
            JSON.parse(ssl_get(uri.to_s, headers))
          end

          def post_request(resource, params = nil)
            uri = URI.parse(MOLLIE_API_V1_URI + resource)
            headers = { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
            data = params.nil? ? nil : JSON.dump(params)
            JSON.parse(ssl_post(uri.to_s, data, headers))
          end
        end

        RedirectError = Class.new(ActiveMerchantError)

        MOLLIE_API_V1_URI = 'https://api.mollie.nl/v1/'.freeze

        mattr_accessor :live_issuers
        self.live_issuers = [
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

        mattr_accessor :test_issuers
        self.test_issuers = [
          ["TBM Bank", "ideal_TESTNL99"]
        ]

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

        def self.redirect_param_label
          "Select your bank"
        end

        def self.redirect_param_options(options = {})
          return test_issuers if options[:credential1].blank?
          options[:credential1].start_with?('live_') ? live_issuers : test_issuers
        end

        def self.retrieve_issuers(token)
          response = API.new(token).get_request("issuers")
          response['data']
            .select { |issuer| issuer['method'] == 'ideal' }
            .map { |issuer| [issuer['name'], issuer['id']] }
        end

        def self.create_payment(token, params)
          API.new(token).post_request('payments', params)
        end

        def self.check_payment_status(token, payment_id)
          API.new(token).get_request("payments/#{payment_id}")
        end
      end
    end
  end
end
