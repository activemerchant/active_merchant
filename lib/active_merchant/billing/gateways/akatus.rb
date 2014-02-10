# -*- encoding : utf-8 -*-
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AkatusGateway < Gateway
      self.test_url = 'https://sandbox.akatus.com/api/v1/'
      self.live_url = 'https://www.akatus.com/api/v1/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['BR']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.money_format = :cents
      self.default_currency = 'BRL'

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.akatus.com/'

      # The name of the gateway
      self.display_name = 'Akatus'

      def initialize(options = {})
        requires!(options, :login, :api_key)
        super
      end

      SUCCESS_STATUS = ['Aguardando Pagamento', 'Em Análise', 'Aprovado']

      CARD_TYPE = {
          'visa'             => 'cartao_visa',
          'master'           => 'cartao_master',
          'american_express' => 'cartao_amex',
          'diners_club'      => 'cartao_dinners'
      }

      def purchase(payment_method, options = {})
        commit(:post, 'carrinho', build_purchase_request(payment_method, options))
      end

      def refund(authorization)
        commit(:post, 'estornar-transacao', build_refund_request(authorization))
      end

      def credit(authorization)
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(authorization)
      end

      def status(autorization)
        commit(:get, autorization, nil)
      end

      private

      def build_purchase_request(payment_method, options)
        xml = Builder::XmlMarkup.new
        xml.instruct! :xml, :encoding => 'UTF-8'

        xml.tag! 'carrinho' do
          xml.tag! 'recebedor' do
            add_credentials(xml)
          end

          xml.tag! 'pagador' do
            add_payer_data(xml, options[:payer])

            xml.tag! 'enderecos' do
              add_address(xml, options[:address] || options[:billing_address])
            end

            xml.tag! 'telefones' do
              add_phone(xml, options[:phone])
            end
          end

          xml.tag! 'produtos' do
            add_line_item_data(xml, options[:line_items])
          end

          xml.tag! 'transacao' do
            add_transaction_data(xml, options[:transaction])
            add_payment_method(xml, payment_method, options)
          end
        end

        xml.target!
      end

      def build_refund_request(transaction)
        xml = Builder::XmlMarkup.new
        xml.instruct! :xml, :encoding => 'UTF-8'

        xml.tag! 'estorno' do
          xml.tag! 'transacao', transaction
          add_credentials(xml)
        end

        xml.target!
      end


      def add_payment_method(xml, payment_method, options)
        if !payment_method.is_a?(String) && payment_method.kind_of?(CreditCard)
          add_creditcard(xml, payment_method, options[:credit_card])
        else
          xml.tag! 'meio_de_pagamento', payment_method
        end
      end

      def add_payer_data(xml, options)
        xml.tag! 'nome', options[:name]
        xml.tag! 'email', options[:email]
      end

      def add_line_item_data(xml, options)
        options.each do |value|
          xml.tag! 'produto' do

            xml.tag! 'comissionamento' do
              xml.tag! 'recebedor', value[:commission][:receiver]
              xml.tag! 'tipo',      value[:commission][:type]
              xml.tag! 'valor',     value[:commission][:type] == 'real' ? amount(value[:commission][:value]) : value[:commission][:value]
            end if value[:commission]

            xml.tag! 'codigo',      value[:id]
            xml.tag! 'descricao',   value[:description]
            xml.tag! 'quantidade',  value[:quantity]
            xml.tag! 'preco',       amount(value[:unit_price])
            xml.tag! 'desconto',    amount(value[:discount]) || 0.0
            xml.tag! 'frete',       amount(value[:freight_amount]) || 0.0
            xml.tag! 'peso',        value[:weight] || 0.0
          end
        end
      end

      def add_address(xml, address)
        xml.tag! 'endereco' do
          xml.tag! 'tipo',        address[:kind] || 'cobranca'
          xml.tag! 'logradouro',  address[:address1]
          xml.tag! 'complemento', address[:address2] if address[:address2]
          xml.tag! 'numero',      address[:number]
          xml.tag! 'bairro',      address[:neighborhood]
          xml.tag! 'cidade',      address[:city]
          xml.tag! 'estado',      address[:state]
          xml.tag! 'cep',         address[:zip]
          xml.tag! 'pais',        address[:country] || 'BRA'
        end
      end

      def add_phone(xml, phone)
        xml.tag! 'telefone' do
          xml.tag! 'tipo',   phone[:kind]
          xml.tag! 'numero', phone[:number]
        end
      end

      def add_transaction_data(xml, transaction)
        xml.tag! 'peso',        transaction[:weight] || 0.0
        xml.tag! 'frete',       transaction[:freight_amount] || 0.0
        xml.tag! 'desconto',    transaction[:discount] || 0.0
        xml.tag! 'moeda',       transaction[:currency] || default_currency
        xml.tag! 'referencia',  transaction[:reference]
      end

      def add_creditcard(xml, creditcard, options)
        xml.tag! 'meio_de_pagamento',   CARD_TYPE[creditcard.brand]
        xml.tag! 'numero',              creditcard.number
        xml.tag! 'expiracao',           "#{format(creditcard.month,:two_digits)}/#{format(creditcard.year, :four_digits)}"
        xml.tag! 'codigo_de_seguranca', creditcard.verification_value if creditcard.verification_value?
        xml.tag! 'parcelas',            options[:plots] || 1

        xml.tag! 'portador' do
          xml.tag! 'nome',     creditcard.name
          xml.tag! 'cpf',      options[:cpf]
          xml.tag! 'telefone', options[:phone]
        end
      end

      def add_credentials(xml)
        xml.tag! 'email',   @options[:login]
        xml.tag! 'api_key', @options[:api_key]
      end

      def commit(method, resource, request)
        http_response = raw_ssl_request(method, url(resource), request, "Content-Type" => "text/xml")

        response = parse(http_response.body)

        Response.new(
            http_response.code.to_i == 442 ? false : success?(response),
            response[:status],
            response,
            :test => test?,
            :authorization => response[:transacao]
        )
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
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def url(resource)
        result = (test? ? self.test_url : self.live_url)
        if resource == 'estornar-transacao' || resource == 'carrinho'
          result += resource + ".xml"
        else
          result += "transacao-simplificada/#{resource}.xml?email=#{@options[:login]}&api_key=#{@options[:api_key]}"
        end
      end

      def success?(response)
        (SUCCESS_STATUS.include?(response[:status]) || response[:'codigo-retorno'] == 0)
      end

    end
  end
end