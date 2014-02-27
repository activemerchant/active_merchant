require File.dirname(__FILE__) + '/mollie_ideal/return.rb'
require File.dirname(__FILE__) + '/mollie_ideal/helper.rb'
require File.dirname(__FILE__) + '/mollie_ideal/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal

        MOLLIE_IDEAL_API_URL = 'https://secure.mollie.nl/xml/ideal'.freeze

        mattr_accessor :production_banklist
        self.production_banklist = [
          ['ABN AMRO', '0031'],
          ['ASN Bank', '0761'],
          ['Friesland Bank', '0091'],
          ['ING', '0721'],
          ['Knab', '0801'],
          ['Rabobank', '0021'],
          ['RegioBank', '0771'],
          ['SNS Bank', '0751'],
          ['Triodos Bank', '0511'],
          ['van Lanschot', '0161']
        ]

        mattr_accessor :testmode_banklist
        self.testmode_banklist = [
          ['TBM Bank', '9999']
        ]

        def self.mollie_api_uri(action, get_params)
          get_params = get_params.merge('testmode' => 'true') if testmode
          params = get_params.merge('a' => action).map do |key, value|
            "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
          end

          URI.parse("#{MOLLIE_IDEAL_API_URL}?#{params.join('&')}")
        end

        def self.mollie_api_request(action, get_params)
          uri = mollie_api_uri(action, get_params)
          site = Net::HTTP.new(uri.host, uri.port)
          site.use_ssl = (uri.scheme == 'https')
          site.verify_mode = OpenSSL::SSL::VERIFY_NONE
          response = site.get(uri.to_s)
          REXML::Document.new(response.body)
        end

        def self.extract_response_parameter(xml, name)
          REXML::XPath.first(xml, "//#{name}").try(:text)
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end

        def self.testmode
          ActiveMerchant::Billing::Base.integration_mode != :production
        end

        def self.banklist(test = nil)
          test = self.testmode if test.nil?
          xml = mollie_api_request(:banklist, {})
          bank_list = []
          REXML::XPath.each(xml, "//bank") do |match|
            name    = REXML::XPath.first(match, "./bank_name").text
            bank_id = REXML::XPath.first(match, "./bank_id").text
            bank_list << [name, bank_id]
          end
          bank_list
        end

        def self.redirect_param_options
          testmode ? self.testmode_banklist : self.production_banklist
        end
      end
    end
  end
end
