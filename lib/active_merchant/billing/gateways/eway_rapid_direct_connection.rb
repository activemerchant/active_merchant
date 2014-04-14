require "nokogiri"
require "cgi"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EwayRapidDirectConnectionGateway < Gateway
      self.test_url = 'https://api.sandbox.ewaypayments.com/'
      self.live_url = 'https://api.ewaypayments.com/'

      self.money_format = :cents
      self.supported_countries = ["AU"]
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.homepage_url = "http://www.eway.com.au/"
      self.display_name = "eWAY Rapid 3.0"
      self.default_currency = "AUD"
      
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(amount, payment, options={})
        request = build_xml_request("DirectPaymentRequest") do |doc|
          add_customer_data(doc, payment, options)
          add_invoice(doc, amount, options)
          add_metadata(doc, options)
        end
        commit(url_for("DirectPayment"), request)
      end

      def refund(amount, authorization, options={})
        request = build_xml_request("DirectRefundRequest") do |doc|
          refund_invoice(doc, amount, authorization, options)
          refund_customer_data(doc, options)
          refund_metadata(doc, options)
        end
        commit(url_for("DirectRefund"), request)
      end

      private

      def build_xml_request(root)
        builder = Nokogiri::XML::Builder.new
        builder.__send__(root) do |doc|
          yield(doc)
        end
        builder.to_xml
      end

      def url_for(action)
        (test? ? test_url : live_url) + action + ".xml"
      end

      def commit(url, request, form_post=false)
        headers = {
          "Authorization" => ("Basic " + Base64.strict_encode64(@options[:login].to_s + ":" + @options[:password].to_s).chomp),
          "Content-Type" => "text/xml"
        }
        
        raw = parse(ssl_post(url, request, headers))
        
        succeeded = success?(raw)
        EwayRapidResponse.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => transaction_from(raw),
          :test => test?,
          :avs_result => avs_result_from(raw),
          :cvv_result => cvv_result_from(raw)
        )
      rescue ActiveMerchant::ResponseError => e
        return EwayRapidResponse.new(false, e.response.message, {:status_code => e.response.code}, :test => test?)
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath("*").each do |node|
          if (node.elements.size == 0)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end unless doc.root.nil?

        response
      end

      def add_invoice(doc, money, options)
        doc.Payment do
          currency_code = options[:currency] || currency(money)
          doc.TotalAmount localized_amount(money, currency_code)
          doc.InvoiceReference options[:order_id]
          doc.InvoiceDescription options[:description]
          doc.CurrencyCode currency_code
        end
      end
      
      def refund_invoice(doc, money, authorization, options)
        doc.Refund do
          
          currency_code = options[:currency] || currency(money)
          doc.TotalAmount localized_amount(money, currency_code)
          doc.InvoiceReference options[:order_id]
          doc.InvoiceDescription options[:description]
          doc.CurrencyCode currency_code
          doc.TransactionID authorization
        end
      end

      def add_metadata(doc, options)
        doc.DeviceID(options[:application_id] || application_id)
        doc.CustomerIP options[:ip] if options[:ip]
        doc.TransactionType "Purchase"
        doc.Method options[:request_method] || "ProcessPayment"
      end 
      
      def refund_metadata(doc, options)
        doc.DeviceID(options[:application_id] || application_id)
        doc.CustomerIP options[:ip] if options[:ip]
        doc.PartnerID options[:partner_id] 
      end

      def add_customer_data(doc, payment, options)
        doc.Customer do
          add_address(doc, (options[:billing_address] || options[:address]), {:email => options[:email]})
          add_credit_card(doc, payment)
        end
        doc.ShippingAddress do
          add_address(doc, (options[:billing_address] || options[:address]), {:email => options[:email]})
        end
      end
      
      def refund_customer_data(doc, options)
        doc.Customer do
          add_address(doc, (options[:billing_address] || options[:address]), {:email => options[:email]})
          refund_credit_card(doc, options)
        end
        doc.ShippingAddress do
          add_address(doc, (options[:billing_address] || options[:address]), {:email => options[:email]})
        end
      end
      
      def add_credit_card(doc, credit_card)
        doc.CardDetails do
          doc.Name credit_card.name
          doc.Number credit_card.number
          doc.ExpiryMonth credit_card.month
          doc.ExpiryYear credit_card.year
          doc.CVN credit_card.verification_value
          doc.IssueNumber credit_card.issue_number
          doc.StartMonth credit_card.start_month
          doc.StartYear credit_card.start_year
        end
      end
      
      def refund_credit_card(doc, options)
        doc.CardDetails do
          doc.ExpiryMonth options[:month]
          doc.ExpiryYear options[:year]
        end
      end
      
      def add_address(doc, address, options={})
        return unless address
        if name = address[:name]
          parts = name.split(/\s+/)
          doc.FirstName parts.shift if parts.size > 1
          doc.LastName parts.join(" ")
        end
        doc.Title address[:title]
        doc.CompanyName address[:company] unless options[:skip_company]
        doc.Street1 address[:address1]
        doc.Street2 address[:address2]
        doc.City address[:city]
        doc.State address[:state]
        doc.PostalCode address[:zip]
        doc.Country address[:country].to_s.downcase
        doc.Phone address[:phone]
        doc.Fax address[:fax]
        doc.Email options[:email]
      end
      
      def success?(response)
        if response[:errors]
          false
        elsif response[:responsecode] == "00"
          true
        elsif response[:transactionstatus]
          (response[:transactionstatus] == "true")
        else
          true
        end
      end

      def message_from(succeeded, response)
        if response[:errors]
          (MESSAGES[response[:errors]] || response[:errors])
        elsif response[:responsecode]
          ActiveMerchant::Billing::EwayGateway::MESSAGES[response[:responsecode]]
        elsif response[:responsemessage]
          (MESSAGES[response[:responsemessage]] || response[:responsemessage])
        elsif succeeded
          "Succeeded"
        else
          "Failed"
        end
      end

      def authorization_from(response)
        response[:authorisationcode]
      end

      def transaction_from(response)
        response[:transactionid]
      end

      def avs_result_from(response)
        code = case response[:verification_address]
        when "Valid"
          "M"
        when "Invalid"
          "N"
        else
          "I"
        end
        {:code => code}
      end

      def cvv_result_from(response)
        case response[:verification_cvn]
        when "Valid"
          "M"
        when "Invalid"
          "N"
        else
          "P"
        end
      end
      
      class EwayRapidResponse < ActiveMerchant::Billing::Response
      end
      
       MESSAGES = {
        'V6000' => 'Validation error',
        'V6001' => 'Invalid CustomerIP',
        'V6002' => 'Invalid DeviceID',
        'V6011' => 'Invalid Payment TotalAmount',
        'V6012' => 'Invalid Payment InvoiceDescription',
        'V6013' => 'Invalid Payment InvoiceNumber',
        'V6014' => 'Invalid Payment InvoiceReference',
        'V6015' => 'Invalid Payment CurrencyCode',
        'V6016' => 'Payment Required',
        'V6017' => 'Payment CurrencyCode Required',
        'V6018' => 'Unknown Payment CurrencyCode',
        'V6021' => 'EWAY_CARDHOLDERNAME Required',
        'V6022' => 'EWAY_CARDNUMBER Required',
        'V6023' => 'EWAY_CARDCVN Required',
        'V6033' => 'Invalid Expiry Date',
        'V6034' => 'Invalid Issue Number',
        'V6035' => 'Invalid Valid From Date',
        'V6040' => 'Invalid TokenCustomerID',
        'V6041' => 'Customer Required',
        'V6042' => 'Customer FirstName Required',
        'V6043' => 'Customer LastName Required',
        'V6044' => 'Customer CountryCode Required',
        'V6045' => 'Customer Title Required',
        'V6046' => 'TokenCustomerID Required',
        'V6047' => 'RedirectURL Required',
        'V6051' => 'Invalid Customer FirstName',
        'V6052' => 'Invalid Customer LastName',
        'V6053' => 'Invalid Customer CountryCode',
        'V6058' => 'Invalid Customer Title',
        'V6059' => 'Invalid RedirectURL',
        'V6060' => 'Invalid TokenCustomerID',
        'V6061' => 'Invalid Customer Reference',
        'V6062' => 'Invalid Customer CompanyName',
        'V6063' => 'Invalid Customer JobDescription',
        'V6064' => 'Invalid Customer Street1',
        'V6065' => 'Invalid Customer Street2',
        'V6066' => 'Invalid Customer City',
        'V6067' => 'Invalid Customer State',
        'V6068' => 'Invalid Customer PostalCode',
        'V6069' => 'Invalid Customer Email',
        'V6070' => 'Invalid Customer Phone',
        'V6071' => 'Invalid Customer Mobile',
        'V6072' => 'Invalid Customer Comments',
        'V6073' => 'Invalid Customer Fax',
        'V6074' => 'Invalid Customer URL',
        'V6075' => 'Invalid ShippingAddress FirstName',
        'V6076' => 'Invalid ShippingAddress LastName',
        'V6077' => 'Invalid ShippingAddress Street1',
        'V6078' => 'Invalid ShippingAddress Street2',
        'V6079' => 'Invalid ShippingAddress City',
        'V6080' => 'Invalid ShippingAddress State',
        'V6081' => 'Invalid ShippingAddress PostalCode',
        'V6082' => 'Invalid ShippingAddress Email',
        'V6083' => 'Invalid ShippingAddress Phone',
        'V6084' => 'Invalid ShippingAddress Country',
        'V6085' => 'Invalid ShippingAddress ShippingMethod',
        'V6086' => 'Invalid ShippingAddress Fax ',
        'V6091' => 'Unknown Customer CountryCode',
        'V6092' => 'Unknown ShippingAddress CountryCode',
        'V6100' => 'Invalid EWAY_CARDNAME',
        'V6101' => 'Invalid EWAY_CARDEXPIRYMONTH',
        'V6102' => 'Invalid EWAY_CARDEXPIRYYEAR',
        'V6103' => 'Invalid EWAY_CARDSTARTMONTH',
        'V6104' => 'Invalid EWAY_CARDSTARTYEAR',
        'V6105' => 'Invalid EWAY_CARDISSUENUMBER',
        'V6106' => 'Invalid EWAY_CARDCVN',
        'V6107' => 'Invalid EWAY_ACCESSCODE',
        'V6108' => 'Invalid CustomerHostAddress',
        'V6109' => 'Invalid UserAgent',
        'V6110' => 'Invalid EWAY_CARDNUMBER'
      }
    end
  end
end
