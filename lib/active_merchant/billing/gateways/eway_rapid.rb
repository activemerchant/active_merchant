require "nokogiri"
require "cgi"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EwayRapidGateway < Gateway
      self.test_url = "https://api.sandbox.ewaypayments.com/"
      self.live_url = "https://api.ewaypayments.com/"

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

      # Public: Run a purchase transaction. Treats the Rapid 3.0 transparent
      # redirect as an API endpoint in order to conform to the standard
      # ActiveMerchant #purchase API.
      #
      # amount  - The monetary amount of the transaction in cents.
      # options - A standard ActiveMerchant options hash:
      #           :order_id         - A merchant-supplied identifier for the
      #                               transaction (optional).
      #           :description      - A merchant-supplied description of the
      #                               transaction (optional).
      #           :currency         - Three letter currency code for the
      #                               transaction (default: "AUD")
      #           :billing_address  - Standard ActiveMerchant address hash
      #                               (optional).
      #           :shipping_address - Standard ActiveMerchant address hash
      #                               (optional).
      #           :ip               - The ip of the consumer initiating the
      #                               transaction (optional).
      #           :application_id   - A string identifying the application
      #                               submitting the transaction
      #                               (default: "https://github.com/Shopify/active_merchant")
      #
      # Returns an ActiveMerchant::Billing::Response object
      def purchase(amount, payment_method, options={})
        MultiResponse.new.tap do |r|
          # Rather than follow the redirect, we detect the 302 and capture the
          # token out of the Location header in the run_purchase step. But we
          # still need a placeholder url to pass to eWay, and that is what
          # example.com is used for here.
          r.process{setup_purchase(amount, options.merge(:redirect_url => "http://example.com/"))}
          r.process{run_purchase(r.authorization, payment_method, r.params["formactionurl"])}
          r.process{status(r.authorization)}
        end
      end

      # Public: Acquire the token necessary to run a transparent redirect.
      #
      # amount  - The monetary amount of the transaction in cents.
      # options - A supplemented ActiveMerchant options hash:
      #           :redirect_url     - The url to return the customer to after
      #                               the transparent redirect is completed
      #                               (required).
      #           :order_id         - A merchant-supplied identifier for the
      #                               transaction (optional).
      #           :description      - A merchant-supplied description of the
      #                               transaction (optional).
      #           :currency         - Three letter currency code for the
      #                               transaction (default: "AUD")
      #           :billing_address  - Standard ActiveMerchant address hash
      #                               (optional).
      #           :shipping_address - Standard ActiveMerchant address hash
      #                               (optional).
      #           :ip               - The ip of the consumer initiating the
      #                               transaction (optional).
      #           :application_id   - A string identifying the application
      #                               submitting the transaction
      #                               (default: "https://github.com/Shopify/active_merchant")
      #
      # Returns an EwayRapidResponse object, which conforms to the
      # ActiveMerchant::Billing::Response API, but also exposes #form_url.
      def setup_purchase(amount, options={})
        requires!(options, :redirect_url)
        request = build_xml_request("CreateAccessCodeRequest") do |doc|
          add_metadata(doc, options)
          add_invoice(doc, amount, options)
          add_customer_data(doc, options)
        end

        commit(url_for("CreateAccessCode"), request)
      end

      # Public: Retrieve the status of a transaction.
      #
      # identification - The Eway Rapid 3.0 access code for the transaction
      #                  (returned as the response.authorization by
      #                  #setup_purchase).
      #
      # Returns an EwayRapidResponse object.
      def status(identification)
        request = build_xml_request("GetAccessCodeResultRequest") do |doc|
          doc.AccessCode identification
        end
        commit(url_for("GetAccessCodeResult"), request)
      end

      private

      def run_purchase(identification, payment_method, endpoint)
        post = {
          "accesscode" => identification
        }
        add_credit_card(post, payment_method)

        commit_form(endpoint, build_form_request(post))
      end

      def add_metadata(doc, options)
        doc.RedirectUrl(options[:redirect_url])
        doc.CustomerIP options[:ip] if options[:ip]
        doc.Method "ProcessPayment"
        doc.DeviceID(options[:application_id] || application_id)
      end

      def add_invoice(doc, money, options)
        doc.Payment do
          doc.TotalAmount amount(money)
          doc.InvoiceReference options[:order_id]
          doc.InvoiceDescription options[:description]
          currency_code = (options[:currency] || currency(money) || default_currency)
          doc.CurrencyCode currency_code
        end
      end

      def add_customer_data(doc, options)
        doc.Customer do
          add_address(doc, (options[:billing_address] || options[:address]), {:email => options[:email]})
        end
        doc.ShippingAddress do
          add_address(doc, options[:shipping_address], {:skip_company => true})
        end
      end

      def add_address(doc, address, options={})
        return unless address
        if name = address[:name]
          parts = name.split(/\s+/)
          doc.FirstName parts.shift if parts.size > 1
          doc.LastName parts.join(" ")
        end
        doc.CompanyName address[:company] unless options[:skip_company]
        doc.Street1 address[:address1]
        doc.Street2 address[:address2]
        doc.City address[:city]
        doc.State address[:state]
        doc.PostalCode address[:zip]
        doc.Country address[:country]
        doc.Phone address[:phone]
        doc.Fax address[:fax]
        doc.Email options[:email]
      end

      def add_credit_card(post, credit_card)
        post["cardname"] = credit_card.name
        post["cardnumber"] = credit_card.number
        post["cardexpirymonth"] = credit_card.month
        post["cardexpiryyear"] = credit_card.year
        post["cardcvn"] = credit_card.verification_value
      end

      def build_xml_request(root)
        builder = Nokogiri::XML::Builder.new
        builder.__send__(root) do |doc|
          yield(doc)
        end
        builder.to_xml
      end

      def build_form_request(post)
        request = []
        post.each do |key, value|
          request << "EWAY_#{key.upcase}=#{CGI.escape(value.to_s)}"
        end
        request.join("&")
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
          :authorization => authorization_from(raw),
          :test => test?,
          :avs_result => avs_result_from(raw),
          :cvv_result => cvv_result_from(raw)
        )
      rescue ActiveMerchant::ResponseError => e
        return EwayRapidResponse.new(false, e.response.message, {:status_code => e.response.code}, :test => test?)
      end

      def commit_form(url, request)
        http_response = raw_ssl_request(:post, url, request)

        success = (http_response.code.to_s == "302")
        message = (success ? "Succeeded" : http_response.body)
        if success
          authorization = CGI.unescape(http_response["Location"].split("=").last)
        end
        Response.new(success, message, {:location => http_response["Location"]}, :authorization => authorization, :test => test?)
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

      def success?(response)
        if response[:errors]
          false
        elsif response[:transactionstatus]
          (response[:transactionstatus] == "true")
        else
          true
        end
      end

      def message_from(succeeded, response)
        if response[:errors]
          response[:errors]
        elsif response[:responsecode]
          ActiveMerchant::Billing::EwayGateway::MESSAGES[response[:responsecode]]
        elsif response[:responsemessage]
          response[:responsemessage]
        elsif succeeded
          "Succeeded"
        else
          "Failed"
        end
      end

      def authorization_from(response)
        response[:accesscode]
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
        def form_url
          params["formactionurl"]
        end
      end
    end
  end
end
