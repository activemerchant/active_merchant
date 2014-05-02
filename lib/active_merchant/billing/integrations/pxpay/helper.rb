require 'active_support/version' # for ActiveSupport2.3
require 'active_support/core_ext/float/rounding.rb' unless ActiveSupport::VERSION::MAJOR > 3 # Float#round(precision)

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Pxpay
        # An example. Note the username as a parameter and transaction key you
        # will want to use later. The amount that you pass in will be *rounded*,
        # so preferably pass in X.2 decimal so that no rounding occurs.  You need
        # to set :credential2 to your PxPay secret key.
        #
        # PxPay accounts have Failproof Notification enabled by default which means
        # in addition to the user being redirected to your return_url, the return_url will
        # be accessed by the PxPay servers directly, immediately after transaction success.
        #
        #  payment_service_for('order_id', 'pxpay_user_ID', :service => :pxpay,
        #                       :amount => 157.0, :currency => 'USD', :credential2 => 'pxpay_key') do |service|
        #
        #   service.customer :email => 'customer@email.com'
        #
        #   service.description 'Order 123 for MyStore'
        #
        #   # Must specify both a return_url or PxPay will show an error instead of
        #   # capturing credit card details.
        #
        #   service.return_url "http://t/pxpay/payment_received_notification_sub_step"
        #
        #   # These fields will be copied verbatim to the Notification
        #   service.custom1 'custom text 1'
        #   service.custom2 ''
        #   service.custom3 ''
        #   # See the helper.rb file for various custom fields
        # end

        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include PostsData

          attr_reader :redirect_parameters

          def initialize(order, account, options = {})
            @redirect_parameters = {
              'PxPayUserId'       => account,
              'TxnId'             => order,
              'PxPayKey'          => options[:credential2],
              'CurrencyInput'     => options[:currency],
              'MerchantReference' => options[:description],
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

            super

            raise "error - must specify return_url"        if redirect_parameters['UrlSuccess'].blank?
            raise "error - must specify cancel_return_url" if redirect_parameters['UrlFail'].blank?
          end

          def credential_based_url
            raw_response = ssl_post(Pxpay.token_url, generate_request)
            result = parse_response(raw_response)

            raise ActionViewHelperError, "error - failed to get token - message was #{result[:redirect]}" unless result[:valid] == "1"

            result[:redirect]
          end

          def form_method
            "GET"
          end

          private
          def generate_request
            xml = REXML::Document.new
            root = xml.add_element('GenerateRequest')

            redirect_parameters.each do | k, v |
              next if v.blank?

              v = v.slice(0, 50) if k == "MerchantReference"
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
