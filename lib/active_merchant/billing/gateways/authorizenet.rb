module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AuthorizenetGateway < Gateway
      require 'nokogiri'
      TRACKS = {
          1 => /^%(?<format_code>.)(?<pan>[\d]{1,19}+)\^(?<name>.{2,26})\^(?<expiration>[\d]{0,4}|\^)(?<service_code>[\d]{0,3}|\^)(?<discretionary_data>.*)\?\Z/,
          2 => /\A;(?<pan>[\d]{1,19}+)=(?<expiration>[\d]{0,4}|=)(?<service_code>[\d]{0,3}|=)(?<discretionary_data>.*)\?\Z/
      }.freeze

      self.test_url = 'https://apitest.authorize.net/xml/v1/request.api'
      self.live_url = 'https://api.authorize.net/xml/v1/request.api'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'AuthorizeNet Gateway'

      def initialize(options={})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment, options = {})
        commit do |xml|
          xml.refId options[:order_id]
          xml.transactionRequest {
            xml.transactionType 'authCaptureTransaction'
            xml.amount money
            add_payment_source(xml, payment)
            #add_invoice(xml, money, options)
            add_customer_data(xml, payment, options)
          }
        end
      end

      def authorize(money, payment, options={})
        commit do |xml|
          xml.refId options[:order_id]
          xml.transactionRequest {
            xml.transactionType 'authOnlyTransaction'
            xml.amount money
            add_payment_source(xml, payment)
            #add_invoice(xml, money, options)
            add_customer_data(xml, payment, options)
          }
        end
      end

      def capture(money, authorization, options={})
        commit do |xml|
          xml.refId options[:order_id] if options.is_a? Hash
          xml.transactionRequest {
            xml.transactionType 'priorAuthCaptureTransaction'
            xml.amount money
            xml.refTransId authorization
          }
        end
      end

      def refund(money, authorization, options={})
        commit do |xml|
          xml.refId options[:order_id]
          xml.transactionRequest {
            xml.transactionType 'refundTransaction'
            xml.amount money unless money.nil?
            xml.refTransId authorization
          }
        end
      end

      def void(authorization, options={})
        commit do |xml|
          xml.refId options[:order_id]
          xml.transactionRequest {
            xml.transactionType 'voidTransaction'
            xml.refTransId authorization
          }
        end
      end

      private
      def add_payment_source(xml, source)
        if card_brand(source) == 'check'
          add_check(xml, source)
        else
          add_creditcard(xml, source)
        end
      end

      def add_creditcard(xml, creditcard)
        if creditcard.track_data.nil?
          xml.payment {
            xml.creditCard {
              xml.cardNumber(creditcard.number.to_s)
              xml.expirationDate(creditcard.month.to_s.rjust(2, '0') + '/' + creditcard.year.to_s)
              xml.cardCode (creditcard.verification_value.to_s) unless creditcard.verification_value.blank?
            }
          }
        else
          add_swipe_data(xml, creditcard)
        end
      end

      def add_swipe_data(xml, credit_card)
        if (TRACKS[1].match(credit_card.track_data))
          xml.payment {
            xml.trackData {
              xml.track1 credit_card.track_data
            }
          }
        else
          xml.payment {
            xml.trackData {
              xml.track2 credit_card.track_data
            }
          }
        end
      end

=begin
      post[:payment] = 'check' # Set transaction to ACH
      post[:checkname] = check.name # The name on the customer's Checking Account
      post[:checkaba] = check.routing_number # The customer's bank routing number
      post[:checkaccount] = check.account_number # The customer's account number
      post[:account_holder_type] = check.account_holder_type # The customer's type of ACH account
      post[:account_type] = check.account_type # The customer's type of ACH account
        :name => 'Jim Smith',
        :bank_name => 'Bank of Elbonia',
        :routing_number => '244183602',
        :account_number => '15378535',
        :account_holder_type => 'personal',
        :account_type => 'checking',
        :number => '1'
accountNumber 	Account number, masked.
	XXXX1111
routingNumber 	Bank's routing number.
	XXXX0000
nameOnAccount 	Name of the person who holds the bank account.

bankName 	The name of the bank.

echeckType
=end
      def add_check(xml, check)
        xml.payment {
          xml.bankAccount {
            xml.routingNumber check.routing_number
            xml.accountNumber check.account_number
            xml.nameOnAccount check.name
            xml.echeckType "WEB"
            xml.bankName check.bank_name
            xml.checkNumber check.number
          }
        }
      end

      def add_customer_data(xml, payment_source, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address] || options[:address]

        xml.customerIP(options[:ip]) unless options[:ip].blank?
        xml.customer {
          xml.email(options[:email]) unless options[:email].blank?
        }
        xml.billTo {
          xml.firstName(payment_source.first_name || parse_first_name(billing_address[:name]))
          xml.lastName(payment_source.last_name || parse_last_name(billing_address[:name]))

          xml.company(billing_address[:company]) unless options[:company].blank?
          xml.address(billing_address[:address1])
          xml.city(billing_address[:city])
          xml.state(billing_address[:state])
          xml.zip(billing_address[:zip])
          xml.country(billing_address[:country])
        }
        xml.shipTo {
          xml.firstName(payment_source.first_name || parse_first_name(shipping_address[:name]))
          xml.lastName(payment_source.last_name || parse_last_name(shipping_address[:name]))

          xml.company(shipping_address[:company]) unless options[:company].blank?
          xml.address(shipping_address[:address1])
          xml.city(shipping_address[:city])
          xml.state(shipping_address[:state])
          xml.zip(shipping_address[:zip])
          xml.country(shipping_address[:country])
        } unless shipping_address.blank?
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(xml, money, options)
        #TODO add_invoice
=begin
        xml.AuthCode options[:force] if options[:force]
        if options[:order_items].blank?
          xml.Total(amount(money)) unless(money.nil? || money < 0.01)
          xml.Description(options[:description]) unless( options[:description].blank?)
        else
          xml.OrderItems {
            options[:order_items].each do |item|
              xml.Item {
                xml.Description(item[:description])
                xml.Cost(amount(item[:cost]))
                xml.Qty(item[:quantity].to_s)
              }
            end
          }
        end
=end
      end

      def parse_first_name(full_name)
        full_name.split()[0]
      end

      def parse_last_name(full_name)
        full_name.split()[1]
      end

      def parse(body)
        response = {}
        doc = Nokogiri::XML(body)
        build_response(response, doc.root, nil, '')
        response
      end

      def build_response(response, node, child_node, name)
        child_node = node if child_node.nil?

        child_node.elements.each do |child_node|
          new_name = "#{name}_#{child_node.name.downcase}"
          response[new_name[1, new_name.length].to_sym] = child_node.text if child_node.elements.empty?
          build_response(response, node, child_node, new_name) unless child_node.elements.empty?
        end
      end

      def commit(&payload)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(&payload), 'Content-Type' => 'text/xml'))

        active_merchant_response = Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            test: test?
        )

        build_avs_response(response, active_merchant_response)
        active_merchant_response
      end

      def post_data
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.createTransactionRequest('xmlns' => 'AnetApi/xml/v1/schema/AnetApiSchema.xsd') {
            xml.merchantAuthentication {
              xml.name @options[:login]
              xml.transactionKey @options[:password]
            }
            yield(xml)
          }
        end
        #TODO: remove this later, debug to see the payload
        #p payload.to_xml(:ident => 0)
        payload.to_xml(:ident => 0)
      end

      def success_from(response)
        response[:messages_message_code] == 'I00001' ? true : false
      end

      def message_from(response)
        if response[:messages_message_text].to_s.include? "The 'AnetApi/xml/v1/schema/AnetApiSchema.xsd:cardNumber' element is invalid"
          'credit card number is invalid.'
        elsif response[:transactionresponse_errors_error_errortext].nil?
          response[:transactionresponse_messages_message_description]
        else
          response[:transactionresponse_errors_error_errortext]
        end
      end

      def authorization_from(response)
        response[:transactionresponse_transid]
      end

      def build_avs_response(response, active_merchant_response)
        code = response[:transactionresponse_avsresultcode]
        active_merchant_response.avs_result['code'] = code
        case code
          when 'Y'
            active_merchant_response.avs_result['street_match'] = true
            active_merchant_response.avs_result['postal_match'] = true
            active_merchant_response.avs_result['message'] = 'Address (Street) and 5 digit ZIP match'
          when 'A'
            active_merchant_response.avs_result['street_match'] = true
            active_merchant_response.avs_result['postal_match'] = false
            active_merchant_response.avs_result['message'] = 'Address (Street) matches, ZIP does not'
          when 'B'
            active_merchant_response.avs_result['message'] = 'Address information not provided for AVS check'
          when 'E'
            active_merchant_response.avs_result['message'] = 'AVS error'
          when 'G'
            active_merchant_response.avs_result['message'] = 'Non-U.S. Card Issuing Bank'
          when 'N'
            active_merchant_response.avs_result['street_match'] = false
            active_merchant_response.avs_result['postal_match'] = false
            active_merchant_response.avs_result['message'] = 'No Match on Address (Street) or ZIP'
        end

        active_merchant_response
      end
    end
  end
end


