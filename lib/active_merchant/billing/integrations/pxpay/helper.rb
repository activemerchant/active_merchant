require 'active_support/core_ext/float/rounding.rb' # Float#round(precision)

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Pxpay
        # An example. Note the username as a parameter and transaction key you
        # will want to use later. The amount that you pass in will be *rounded*,
        # so preferably pass in X.2 decimal so that no rounding occurs. It is
        # rounded because if it looks like 00.000 Authorize.Net fails the
        # transaction as incorrectly formatted.
        # 
        #  payment_service_for('order_id', 'pxpay user ID', :service => :pxpay,  :amount => 157.0) do |service|
        # 
        #    # You must set :credential2 to your pxpay key
        #    
        #    service.customer_id 8
        #    service.customer :first_name => 'g',
        #                       :last_name => 'g',
        #                       :email => 'g@g.com',
        #                       :phone => '3'
        #   service.billing_address :zip => 'g',
        #                   :country => 'United States of America',
        #                   :address => 'g'
        # 
        #   service.ship_to_address :first_name => 'g',
        #                            :last_name => 'g',
        #                            :city => '',
        #                            :address => 'g',
        #                            :address2 => '',
        #                            :state => address.state,
        #                            :country => 'United States of America',
        #                            :zip => 'g'
        # 
        #   service.invoice "516428355" # your invoice number
        #   # The end-user is presented with the HTML produced by the notify_url.
        #   service.return_url "http://t/pxpay/payment_received_notification_sub_step"
        #   service.return_cancel_url "http://t/pxpay/payment_cancelled"
        #   service.payment_header 'My store name'
        #   # See the helper.rb file for various custom fields
        # end
         
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include PostsData
          mapping :account, 'PxPayUserId'
          mapping :credential2, 'PxPayKey'
          mapping :return_url, 'UrlSuccess'
          mapping :cancel_return_url, 'UrlFail'
          mapping :currency, 'CurrencyInput'
          mapping :order_info, 'MerchantReference'
          mapping :order, 'TxnId'
          mapping :customer, :email => 'EmailAddress'
          
          # Set the billing address. Call like service.billing_address {:city =>
          # 'provo, :state => 'UT'}...
          def billing_address(options)
            raise 'must use address1 and address2' if options[:address]

            # these fields are not required
            add_field 'TxnData1', (options[:address1].to_s + ' ' + options[:address2].to_s).strip
            add_field 'TxnData2', options[:city]
            add_field 'TxnData3', options[:country]
          end
          
          # Adds a custom field which you submit to Authorize.Net. These fields
          # are all passed back to you verbatim when it does its relay
          # (callback) to you note that if you call it twice with the same name,
          # this function only uses keeps the second value you called it with.          
          def add_custom_field(name, value)
            add_field 'Opt', "#{name}=#{value}"
          end

          def generate_request
            xml = REXML::Document.new()
            root = xml.add_element('GenerateRequest')

            @fields.each do | k, v |
              root.add_element(k).text = v
            end

            xml.to_s
          end

          def request_secure_redirect
            request = generate_request

            response = ssl_post(Pxpay.token_url, request)
            xml = REXML::Document.new(response)
            root = REXML::XPath.first(xml, "//Request")
            valid = root.attributes["valid"]
            redirect = root.elements["URI"].text

            # example positive response:
            # <Request valid="1"><URI>https://sec.paymentexpress.com/pxpay/pxpay.aspx?userid=ShopifyHPP_Dev&amp;request=REQUEST_TOKEN</URI></Request>
            
            # example negative response:
            # <Request valid="0"><URI>Invalid TxnType</URI></Request>

            {:valid => valid, :redirect => redirect}
          end

          def form_fields
            # if either return URLs are blank PxPay will generate a token but redirect user to error page.
            raise "error - must specify return_url" if @fields['UrlSuccess'].blank?
            raise "error - must specify cancel_return_url" if @fields['UrlFail'].blank?

            result = request_secure_redirect
            raise "error - failed to get token - message was #{result[:redirect]}" unless result[:valid] == "1"
     
            url = URI.parse(result[:redirect])

            CGI.parse(url.query)
          end
          
          def form_method
            "GET"
          end

          # Note that you should call #invoice and #setup_hash as well, for the
          # response_url to actually work.
          def initialize(order, account, options = {})
            super
            raise 'missing parameter' unless order and account and options[:amount]
            raise 'error -- amount with no digits!' unless options[:amount].to_s =~ /\d/

            add_field 'AmountInput', "%.2f" % options[:amount].to_f.round(2)
          	add_field 'EnableAddBillCard', '0'
            add_field 'TxnType', 'Purchase'
          end

        end
      end
    end
  end
end
