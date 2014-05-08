require 'active_support/version' # for ActiveSupport2.3
require 'active_support/core_ext/float/rounding.rb' unless ActiveSupport::VERSION::MAJOR > 3 # Float#round(precision)

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Pxpay
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include PostsData

          attr_reader :token_parameters, :redirect_parameters

          def initialize(order, account, options = {})
            @token_parameters = {
              'PxPayUserId'       => account,
              'PxPayKey'          => options[:credential2],
              'CurrencyInput'     => options[:currency],
              'MerchantReference' => order,
              'EmailAddress'      => options[:customer_email],
              'TxnData1'          => options[:custom1],
              'TxnData2'          => options[:custom2],
              'TxnData3'          => options[:custom3],
              'AmountInput'       => "%.2f" % options[:amount].to_f.round(2),
              'EnableAddBillCard' => '0',
              'TxnType'           => 'Purchase',
              'UrlSuccess'        => options[:return_url],
              'UrlFail'           => options[:return_url]
            }
            @redirect_parameters = {}

            super

            raise ArgumentError, "error - must specify return_url"        if token_parameters['UrlSuccess'].blank?
            raise ArgumentError, "error - must specify cancel_return_url" if token_parameters['UrlFail'].blank?
          end

          def credential_based_url
            raw_response = ssl_post(Pxpay.token_url, generate_request)
            result = parse_response(raw_response)

            raise ActionViewHelperError, "error - failed to get token - message was #{result[:redirect]}" unless result[:valid] == "1"

            url = URI.parse(result[:redirect])

            if url.query
              @redirect_parameters = CGI.parse(url.query)
              url.query = nil
            end

            url.to_s
          end

          def form_method
            "GET"
          end

          def form_fields
            redirect_parameters
          end

          private
          def generate_request
            xml = REXML::Document.new
            root = xml.add_element('GenerateRequest')

            token_parameters.each do | k, v |
              next if v.blank?

              v = v.to_s.slice(0, 50) if k == "MerchantReference"
              root.add_element(k).text = v
            end

            xml.to_s
          end

          def parse_response(raw_response)
            xml = REXML::Document.new(raw_response)
            root = REXML::XPath.first(xml, "//Request")
            valid = root.attributes["valid"]
            redirect = root.elements["URI"].try(:text)
            valid, redirect = "0", root.elements["ResponseText"].try(:text) unless redirect

            # example valid response:
            # <Request valid="1"><URI>https://sec.paymentexpress.com/pxpay/pxpay.aspx?userid=PxpayUser&amp;request=REQUEST_TOKEN</URI></Request>
            # <Request valid='1'><Reco>IP</Reco><ResponseText>Invalid Access Info</ResponseText></Request>

            # example invalid response:
            # <Request valid="0"><URI>Invalid TxnType</URI></Request>

            {:valid => valid, :redirect => redirect}
          end
        end
      end
    end
  end
end
