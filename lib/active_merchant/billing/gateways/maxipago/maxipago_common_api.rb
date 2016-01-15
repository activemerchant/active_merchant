module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in MaxipagoGateway
    module MaxipagoCommonAPI
      API_VERSION = '3.1.1.15'

      URLS = {
        :test => { :transaction => 'https://testapi.maxipago.net/UniversalAPI/postXML',
                   :api         => 'https://testapi.maxipago.net/UniversalAPI/postAPI',
                   :report      => 'https://testapi.maxipago.net/ReportsAPI/servlet/ReportsAPI' },
        :live => { :transaction => 'https://api.maxipago.net/UniversalAPI/postXML',
                   :api         => 'https://api.maxipago.net/UniversalAPI/postAPI',
                   :report      => 'https://api.maxipago.net/ReportsAPI/servlet/ReportsAPI' },
      }

      def self.included(base)
        base.live_url = URLS[:live][:transaction]
        base.test_url = URLS[:test][:transaction]

        base.supported_countries = %w(BR)
        base.supported_cardtypes = %i(visa master discover american_express diners_club)
        base.supported_banks = %i(itau)
        base.supported_boletos = %i(itau bradesco)
        base.homepage_url = 'http://www.maxipago.com/'
        base.display_fullname = 'MaxiPago'
        base.display_name = 'MaxiPago'
        base.display_logo = 'https://cdn.edools.com/assets/images/gateways/maxiPago.png'
        base.default_currency = 'BRL'
        base.money_format = :dollars
      end

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def common_purchase(money, creditcard, options)
        post = {}
        add_aux_data(post, options)
        add_amount(post, money)
        add_creditcard(post, creditcard)
        add_name(post, creditcard)
        add_address(post, options)

        commit(build_sale_request(post))
      end

      private

      def add_aux_data(post, options)
        processor_id = options[:processor_id] || 4 # test: 1, redecard: 2, cielo: 4
        post[:processorID]  = (test? ? 1 : processor_id)
        post[:referenceNum] = options[:order_id]
        post[:installments] = options[:installments] if options.has_key?(:installments) && options[:installments] > 1 # only send installments if it is a deferred payment
      end

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_creditcard(post, creditcard)
        post[:card_number] = creditcard.number
        post[:card_exp_month] = creditcard.month
        post[:card_exp_year] = creditcard.year
        post[:card_cvv] = creditcard.verification_value
      end

      def add_name(post, creditcard)
        post[:billing_name] = creditcard.name
      end

      def add_payer_name(post, options)
        post[:billing_name] = options[:payer][:name]
      end

      def add_address(post, options)
        if(address = (options[:address] || options[:billing_address]))
          post[:billing_address] = address[:address1]
          post[:billing_address2] = address[:address2]
          post[:billing_city] = address[:city]
          post[:billing_state] = address[:state]
          post[:billing_postalcode] = address[:zip]
          post[:billing_country] = address[:country]
          post[:billing_phone] = address[:phone]
        end
      end

      def commit(request, type = :transaction)
        url = (test? ? URLS[:test][type] : URLS[:live][type])
        response = parse(ssl_post(url, request, 'Content-Type' => 'text/xml'))
        Response.new(
          success?(response),
          message_from(response),
          response,
          test: test?,
          authorization: response[:order_id]
        )
      end

      def success?(response)
        (response[:response_code] == '0')
      end

      def message_from(response)
        return response[:error_message] if response[:error_message].present?
        return response[:processor_message] if response[:processor_message].present?
        return response[:response_message] if response[:response_message].present?
        return (success?(response) ? 'success' : 'error')
      end

      def build_sale_request(params, action="sale")
        build_transaction_request(params) do |xml|
          xml.send(action) {
            xml.processorID params[:processorID]
            xml.fraudCheck 'N' unless params[:recurring].present?
            xml.referenceNum params[:referenceNum] # spree_order
            xml.customerIdExt params[:customer_identifier] if params[:payment_type] == :bank_transfer
            xml.transactionDetail {
              xml.payType {
                if params[:payment_type] == :boleto
                  xml.boleto {
                    xml.expirationDate params[:expiration_date]
                    xml.number params[:number]
                    xml.instructions params[:instructions]
                  }
                elsif params[:payment_type] == :bank_transfer
                  xml.onlineDebit {
                    xml.parametersURL params[:url_params] if params[:url_params]
                  }
                else
                  xml.creditCard {
                    xml.number params[:card_number]
                    xml.expMonth params[:card_exp_month]
                    xml.expYear params[:card_exp_year]
                    xml.cvvNumber params[:card_cvv]
                  }
                end
              }
            }
            xml.payment {
              xml.chargeTotal params[:amount]
              if params[:installments].present? && !params[:recurring].present?
                xml.creditInstallment {
                  xml.numberOfInstallments params[:installments]
                  xml.chargeInterest 'N'
                }
              end
            }
            xml.billing {
              xml.name params[:billing_name]
              xml.address params[:billing_address] if params[:billing_address].present?
              xml.address2 params[:billing_address2] if params[:billing_address2].present?
              xml.city params[:billing_city] if params[:billing_city].present?
              xml.state params[:billing_state] if params[:billing_state].present?
              xml.postalcode params[:billing_postalcode] if params[:billing_postalcode].present?
              xml.country params[:billing_country] if params[:billing_country].present?
              xml.phone params[:billing_phone] if params[:billing_phone].present?
            }
            if params[:recurring]
              xml.recurring {
                xml.action 'new'
                xml.startDate params[:recurring][:start_date]
                xml.frequency params[:recurring][:frequency]
                xml.period params[:recurring][:period]
                xml.installments params[:recurring][:installments]
                xml.failureThreshold params[:recurring][:failureThreshold]
              }
            end
          }
        end
      end

      def build_detail_request(params)
        build_report_request('transactionDetailReport') do |xml|
          xml.filterOptions {
            xml.transactionId params[:transaction_id] if params[:transaction_id]
            xml.orderId params[:order_id] if params[:order_id]
          }
        end
      end

      def build_transaction_request(params)
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.send("transaction-request") {
            xml.version API_VERSION
            xml.verification {
              xml.merchantId @options[:login]
              xml.merchantKey @options[:password]
            }
            xml.order {
              yield(xml)
            }
          }
        end
        builder.to_xml(indent: 2)
      end

      def build_api_request(command, order_id)
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.send("api-request") {
            xml.verification {
              xml.merchantId @options[:login]
              xml.merchantKey @options[:password]
            }
            xml.command command
            xml.request {
              xml.orderID order_id
            }
          }
        end
        builder.to_xml(indent: 2)
      end

      def build_report_request(command)
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.send("rapi-request") {
            xml.verification {
              xml.merchantId @options[:login]
              xml.merchantKey @options[:password]
            }
            xml.command command
            xml.request { yield(xml) }
          }
        end
        builder.to_xml(indent: 2)
      end

      def parse(body)
        xml = REXML::Document.new(body)

        response = {}
        xml.root.elements.to_a.each do |node|
          parse_element(response, node)
        end
        response
      end

      def parse_element(response, node)
        if node.has_elements?
          if node.name == 'records'
            parse_records(response, node)
            node = node.elements[1]
          end
          # there is not a else to allow values of last record (which is in position 1)
          # to be in responses root

          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def parse_records(response, node)
        records = []
        node.elements.each do |record|
          record_hash = {}
          record.elements.each { |element| parse_element(record_hash, element)}
          records << record_hash
        end
        response[:records] = records
      end

    end
  end
end
