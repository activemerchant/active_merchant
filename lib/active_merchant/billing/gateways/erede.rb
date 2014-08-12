module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EredeGateway < Gateway

      self.test_url = 'https://scommerce.userede.com.br/Beta/wsTransaction'
      self.live_url = 'https://ecommerce.userede.com.br/Transaction/wsTransaction'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.supported_cardtypes = [:visa, :master, :diners]

      self.homepage_url = 'http://www.userede.com.br/pt-BR/Paginas/default.aspx'
      self.display_name = 'RedeCard e-Rede'

      INSTALMENT_TYPES = [
        :interest_bearing, :zero_interest
      ]

      def initialize(options={})
        requires!(options, :login, :password, :affiliate)
        super
      end

      def purchase(money, credit_card, options={})
        @credit_card = credit_card
        requires!(options, :buyer_cpf, :billing_address)
        requires!(options, :first_name, :last_name, :expiry_date) unless credit_card_payment?
        xml = create_request do |xml|
          add_authentication(xml, options)
          add_transaction(xml, money, credit_card, options)
          add_instalments(xml, options) if options.fetch(:instalments, {})[:number]
        end
        commit(xml)
      end

      def authorize(money, credit_card, options={})
      end

      def capture(money, authorization, options={})
      end

      def refund(money, authorization, options={})
      end

      def void(authorization, options={})
      end

      private

      def credit_card_payment?
        @credit_card.is_a? ActiveMerchant::Billing::CreditCard
      end

      def boleto_payment?
        @credit_card.to_sym == :boleto
      end

      def create_request
        xml = Builder::XmlMarkup.new
        xml.Request version: '2' do |request_xml|
          yield request_xml
        end
        xml
      end

      def add_authentication(xml, options)
        xml.Authentication {
          xml.AcquirerCode {
            xml.rdcd_pv @options[:affiliate]
          }
          xml.password @options[:password]
        }
      end

      def add_transaction(xml, money, credit_card, options)
        xml.Transaction {
          if credit_card_payment?
            xml.CardTxn {
              xml.method 'auth'
              add_credit_card(xml, credit_card, options)
            }
          elsif boleto_payment?
            xml.BoletoTxn {
              xml.method 'payment'
              xml.expiry_date options[:expiry_date]
              xml.instructions options[:instructions]
              xml.last_name options[:last_name]
              xml.first_name options[:first_name]
            }
          else
            raise Exception('Invalid payment method.')
          end
          xml.TxnDetails {
            xml.merchantreference options[:order_id]
            xml.amount amount(money), currency: default_currency
            xml.capturemethod 'ecomm'
          }
        }
      end

      def add_credit_card(xml, credit_card, options)
        card_expire_month = credit_card.month.to_s.rjust(2, '0')
        card_expire_year = credit_card.year.to_s.slice(-2, 2)
        card_expire_date = "#{card_expire_month}/#{card_expire_year}"
        xml.Card {
          xml.pan credit_card.number
          xml.expirydate card_expire_date
          xml.card_account_type('debit') if options[:debit_card]
          add_avs_data(xml, credit_card, options)
        }
      end

      def add_avs_data(xml, credit_card, options)
        xml.Cv2Avs {
          xml.street_address1 options[:billing_address][:number]
          xml.street_address2 options[:billing_address][:street]
          xml.street_address3 options[:billing_address][:neighborhood]
          xml.street_address4 options[:billing_address][:additional_info]
          xml.city options[:billing_address][:city]
          xml.state_province options[:billing_address][:state]
          xml.country options[:billing_address][:country]
          xml.postcode options[:billing_address][:postcode]
          xml.cv2 credit_card.verification_value
          xml.cpf options[:buyer_cpf]
          xml.policy options[:policy] || 3
        }
      end

      def add_instalments(xml, options)
        type = options[:instalments][:type]
        raise Exception('invalid instalment type.') unless INSTALMENT_TYPES.include? type
        instalments = options[:instalments][:number].to_i
        xml.Instalments {
          xml.type type
          xml.number instalments
        }
      end

      def commit(xml)
        url = build_commit_url

        response = parse(ssl_post(url, xml.target!))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def build_commit_url
        url = (test? ? test_url : live_url)
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
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text.to_s.strip
        end
      end

      def success_from(response)
        response[:status] == '1'
      end

      def message_from(response)
        return response[:cv2avs_status] unless response[:status] == '1'
        if credit_card_payment?
          response[:extended_response_message]
        elsif boleto_payment?
          response[:reason]
        else
          raise Exception('Invalid payment method.')
        end
      end

      def authorization_from(response)
        if credit_card_payment?
          response[:authcode]
        else
          {
            gateway_reference: response[:gateway_reference],
            boleto_url: response[:boleto_url]
          }
        end
      end
    end
  end
end
