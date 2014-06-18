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
          xml.refId options[:order_id] if options.is_a? Hash
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
          xml.refId options[:order_id] if options.is_a? Hash
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
            xml.refTransId authorization.split('#')[0]
          }
        end
      end

      def refund(money, authorization, options={})
        commit do |xml|
          xml.transactionRequest {
            xml.transactionType 'refundTransaction'
            xml.amount money unless money.nil?
            xml.payment {
              xml.creditCard {
                xml.cardNumber(authorization.split('#')[1])
                xml.expirationDate 'XXXX'
              }
            }
            xml.refTransId authorization.split('#')[0]
          }
        end
      end

      def void(authorization, options={})
        commit do |xml|
          xml.refId options[:order_id]
          xml.transactionRequest {
            xml.transactionType 'voidTransaction'
            xml.refTransId authorization.split('#')[0]
          }
        end
      end

      private
      def add_payment_source(xml, source)
        if card_brand(source) == 'check'
          add_check(xml, source)
        else
          add_credit_card(xml, source) unless source.nil?
        end
      end

      def add_credit_card(xml, creditcard)
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
        elsif (TRACKS[2].match(credit_card.track_data))
          xml.payment {
            xml.trackData {
              xml.track2 credit_card.track_data
            }
          }
        end
      end

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
        #attr_accessor :invoice_num, :description, :tax, :tax_name, :tax_description, :freight, :freight_name,
        #:freight_description, :duty, :duty_name, :duty_description, :tax_exempt, :po_num, :line_items
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
            test: test?,
            avs_result: build_avs_result(response),
            cvv_result: build_cvv_result(response)
        )

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
        account_number = response[:transactionresponse_accountnumber]
        if (!account_number.nil?) && (account_number.include? 'XXXX')
           account_number = account_number[-4..-1]
        end

        response[:transactionresponse_transid] + '#' + account_number unless response[:transactionresponse_transid].nil? || account_number.nil? || account_number.empty?
      end

      def build_avs_result(response)
        avs_result = nil

        case response[:transactionresponse_avsresultcode]
          when 'A'
            avs_result = AVSResult.new ({:code => 'A'})
          when 'B'
            avs_result = AVSResult.new ({:code => 'U'})
          when 'E'
            avs_result = AVSResult.new ({:code => 'E'})
          when 'G'
            avs_result = AVSResult.new ({:code => 'G'})
          when 'N'
            avs_result = AVSResult.new ({:code => 'C'})
          when 'P'
            avs_result = AVSResult.new ({:code => 'E'})
          when 'R'
            avs_result = AVSResult.new ({:code => 'R'})
          when 'S'
            avs_result = AVSResult.new ({:code => 'S'})
          when 'U'
            avs_result = AVSResult.new ({:code => 'U'})
          when 'W'
            avs_result = AVSResult.new ({:code => 'W'})
          when 'X'
            avs_result = AVSResult.new ({:code => 'X'})
          when 'Y'
            avs_result = AVSResult.new ({:code => 'Y'})
          when 'Z'
            avs_result = AVSResult.new ({:code => 'Z'})
        end
        avs_result
      end

      def build_cvv_result(response)
        cvv_result = CVVResult.new response[:transactionresponse_cvvresultcode]
      end
    end
  end
end


