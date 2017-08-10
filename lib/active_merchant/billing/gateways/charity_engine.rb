require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CharityEngineGateway < Gateway
      include Empty
      URL = 'https://api.charityengine.net/api.asmx'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://charityengine.net/'
      self.display_name = 'Charity Engine'
      self.money_format = :dollars

      SOAP_ACTION_NS = 'https://api.bisglobal.net/'
      SOAP_XMLNS = { xmlns: 'https://api.bisglobal.net/' }
      NS = {
        'xmlns:xsi'  => 'http://www.w3.org/2001/XMLSchema-instance',
        'xmlns:xsd'  => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope'
      }

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      def purchase(money, payment_method, options={})
        request = build_soap_request do |xml|
          xml.ChargeCreditCard(SOAP_XMLNS) do
            add_authentication(xml)
            xml.parameters do
              xml.Charges do
                xml.ChargeCreditCardParameters do
                  add_invoice(xml, money)
                  add_billing_address(xml, options)
                  add_credit_card(xml, payment_method)
                  add_customer_details(xml, options) if options[:customer].present?
                  add_attribution_details(xml, options) if options[:attribution].present?
                  add_send_receipt(xml, options)
                end
              end
            end
          end
        end

        commit('ChargeCreditCard', request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<Username>)[^<]*(</Username>))i, '\1[FILTERED]\2').
          gsub(%r((<Password>)[^<]*(</Password>))i, '\1[FILTERED]\2').
          gsub(%r((<CreditCardNumber>)[^<]*(</CreditCardNumber>))i, '\1[FILTERED]\2')
      end

      private

      def add_address(xml, options={})
        address = options[:billing_address] || options[:address]
        if address.present?
          xml.AddressStreet1 address[:address1] unless empty?(address[:address1])
          xml.AddressStreet2 address[:address2] unless empty?(address[:address2])
          xml.AddressCity address[:city] unless empty?(address[:city])
          xml.AddressState address[:state] unless empty?(address[:state])
          xml.AddressPostalCode address[:zip] unless empty?(address[:zip])
        end
      end

      def add_billing_address(xml, options={})
        billing_address = options[:billing_address] || options[:address]
        if billing_address.present?
          xml.CustomerBillingInfo do
            xml.BillingAddressStreet1 billing_address[:address1] unless empty?(billing_address[:address1])
            xml.BillingAddressStreet2 billing_address[:address2] unless empty?(billing_address[:address2])
            xml.BillingAddressCity billing_address[:city] unless empty?(billing_address[:city])
            xml.BillingAddressStateProvince billing_address[:state] unless empty?(billing_address[:state])
            xml.BillingAddressPostalCode billing_address[:zip] unless empty?(billing_address[:zip])
          end
        end
      end

      def add_invoice(xml, money, options={})
        xml.Amount amount(money)
        xml.TaxDeductibleAmount amount(money)
      end

      # defaults to true
      # option[:receipt] is expected to be a boolean
      # if it is not present, as directed by CE, this should be true
      # it's more of an opt-out setup
      def add_send_receipt(xml, options={})
        xml.SendReceipt options.key?(:receipt) ? options[:receipt] : true
      end

      def add_credit_card(xml, creditcard)
        xml.CreditCardInfo do
          xml.CreditCardNumber creditcard.number
          xml.CreditCardExpirationMonth format(creditcard.month, :two_digits)
          xml.CreditCardExpirationYear format(creditcard.year, :four_digits)
          xml.CreditCardNameOnCard creditcard.name
        end
      end

      def add_customer_details(xml, options={})
        customer = options[:customer]
        if customer.present?
          xml.Contact do
            xml.FirstName customer[:first_name]
            xml.LastName customer[:last_name]
            xml.PrimaryEmailAddress customer[:email]
            xml.PrimaryPhone customer[:phone_number]
            xml.BirthDate customer[:dob] unless empty?(customer[:dob])
            xml.Gender customer[:gender] unless empty?(customer[:gender])
            xml.ContactType 'Person'
            add_address(xml, options)
          end
        end
      end

      def add_attribution_details(xml, options={})
        attribution = options[:attribution]
        if attribution.present?
          xml.Attribution do
            xml.ResponseChannel_Id attribution[:response_channel_id] unless empty?(attribution[:response_channel_id])
            xml.Initiative_Id attribution[:initiative_id] unless empty?(attribution[:initiative_id])
            xml.InitiativeSegment_Id attribution[:initiative_segment_id] unless empty?(attribution[:initiative_segment_id])
            add_tracking_codes(xml, attribution[:tracking_codes]) unless empty?(attribution[:tracking_codes])
          end
        end
      end

      # tracking codes are expected in the `attribution[:tracking_codes]` datastructure
      # as `code1: '123', code2: 'foo' ... `
      def add_tracking_codes(xml, options={})
        we_have_at_least_one_code = false
        (1..8).each { |i| we_have_at_least_one_code = true if options.key?("code#{i}".to_sym) }
        return unless we_have_at_least_one_code
        xml.TrackingCodes do
          (1..8).each do |counter|
            xml.send("Code#{counter}", options["code#{counter}".to_sym]) unless empty?(options["code#{counter}".to_sym])
          end
        end
      end

      def parse(action, body)
        parsed = {}

        doc = Nokogiri::XML(body).remove_namespaces!
        doc.xpath("//#{action}Response/#{action}Result/*").each do |node|
          if (node.elements.empty?)
            parsed[node.name.underscore.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name}_#{childnode.name}"
              # there's a deep-nest XML data structure that we want to extract
              if name.underscore == "charges_transaction_detail"
                childnode.elements.each do |grandchildnode|
                  subname = "#{name}_#{grandchildnode.name}"
                  parsed[subname.underscore.to_sym] = grandchildnode.text
                end
              else
                # no deep nesting in the other elements or we don't care
                parsed[name.underscore.to_sym] = childnode.text
              end
            end
          end
        end

        parsed
      end

      def commit(action, xml)
        response = parse(action, ssl_post(URL, xml, headers(action)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def add_authentication(xml)
        xml.credentials do
          xml.Username(@options[:username])
          xml.Password(@options[:password])
          xml.AuthenticationType 'WebServiceUser'
        end
      end

      def headers(action)
        {
          'Content-Type'    => 'text/xml',
          'SOAPAction'      => "#{SOAP_ACTION_NS}#{action}",
        }
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['soap12'].Envelope(NS) do
            xml['soap12'].Body do
              yield(xml)
            end
          end
        end

        builder.to_xml
      end

      def success_from(response)
        response[:successful] == 'true' && response[:error_message_code] == '0' && \
        response[:charges_transaction_detail_payment_successful] == 'true'
      end

      def message_from(response)
        if success_from(response)
          # it's not clear if there's a message when there's a successful transaction
        else
          if response[:error_message_code] != '0'
            "#{response[:error_message_code]} - #{response[:error_message_description]}"
          else
            response[:charges_transaction_detail_decline_details]
          end
        end
      end

      def authorization_from(response)
        response[:charges_transaction_detail_transaction_id]
      end

      def error_code_from(response)
        # we don't really seem to be getting errors from the API
        # except if the call to the API itself failed, like 100 for invalid login
        # but that's about it.
      end
    end
  end
end
