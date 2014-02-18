module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MoipGateway < Gateway
      self.test_url = 'https://desenvolvedor.moip.com.br/sandbox'
      self.live_url = 'https://www.moip.com.br'

      self.supported_countries = ['BR']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.homepage_url = 'https://www.moip.com.br/'
      self.display_name = 'Moip'
      self.default_currency = 'BRL'

      def initialize(options = {})
        requires!(options, :token, :api_key)
        super
      end

      URL_ACTIONS = {
          'authorize' => '/ws/alpha/EnviarInstrucao/Unica',
          'capture'   => '/rest/pagamento?callback=?&'
      }

      CARD_BRAND = {
          'visa'             => 'Visa',
          'master'           => 'Mastercard',
          'diners_club'      => 'Diners',
          'american_express' => 'AmericanExpress'
      }

      PAYMENT_METHODS = {
          'itau'             => 'DebitoBancario',
          'bradesco'         => 'DebitoBancario',
          'banrisul'         => 'DebitoBancario',
          'banco_do_brasil'  => 'DebitoBancario',
          'boleto_bancario'  => 'BoletoBancario',
          'visa'             => 'CartaoCredito',
          'master'           => 'CartaoCredito',
          'diners_club'      => 'CartaoCredito',
          'american_express' => 'CartaoCredito'
      }

      def authorize(money, payment_method, options = {})
        commit(:post, 'xml', build_url('authorize'), build_authorize_request(money, payment_method, options), add_authentication)
      end

      def purchase(money, payment_method, options = {})
        MultiResponse.run do |r|
          r.process{authorize(money, payment_method, options)}
          r.process{capture(r.authorization, payment_method, options)}
        end
      end

      def capture(authorization, payment_method, options = {})
        commit(:get, 'json', build_url('capture', build_capture_params(authorization, payment_method, options)), nil)
      end

      private

      def build_authorize_request(money, payment_method, options)
        xml = Builder::XmlMarkup.new
        xml.tag! 'EnviarInstrucao' do
          xml.tag! 'InstrucaoUnica', TipoValidacao: 'Transparente' do

            xml.tag! 'IdProprio', options[:order_id]
            xml.tag! 'Razao',     options[:reason]

            xml.tag! 'Pagamento' do
              xml.tag! 'FormaPagamento', payment_methods(payment_method)
            end

            xml.tag! 'Valores' do
              currency = options[:currency] || default_currency
              xml.tag! 'Valor',     amount(money),                moeda: currency
              xml.tag! 'Acrescimo', amount(options[:additional]), moeda: currency unless options[:additional].blank?
              xml.tag! 'Deducao',   amount(options[:discount]),   moeda: currency unless options[:discount].blank?
            end

            xml.tag! 'Pagador' do
              add_customer_data(xml, options[:payer])
              add_address(xml, options[:address] || options[:billing_address])
            end

            add_commissions(xml, options[:commissions])           unless options[:commissions].blank?
            add_installments_options(xml, options[:installments]) unless options[:installments].blank?
            add_receiver(xml, options[:receiver])                 unless options[:receiver].blank?
            add_payment_slip_data(xml, options[:payment_slip])    unless options[:payment_slip].blank?

            xml.tag! 'URLNotificacao', options[:notification_url] unless options[:notification_url].blank?
            xml.tag! 'URLRetorno', options[:return_url]           unless options[:return_url].blank?

          end
        end

        xml.target!
      end

      def build_capture_params(authorization, payment_method, options)
        params = {
            :pagamentoWidget => {
                :token => authorization,
                :referer => options[:referer],
                :dadosPagamento => {
                    :Forma => payment_methods(payment_method)
                }
            }
        }

        case params[:pagamentoWidget][:dadosPagamento][:Forma]
          when 'CartaoCredito'
            requires!(options, :creditcard)
            add_creditcard(params[:pagamentoWidget][:dadosPagamento], payment_method, options[:creditcard])
          when 'DebitoBancario'
            params[:pagamentoWidget][:dadosPagamento][:Instituicao] = payment_method.classify
        end

        {
            :pagamentoWidget => params.to_json
        }
      end

      def payment_methods(method)
        if method.is_a?(CreditCard)
          'CartaoCredito'
        else
          PAYMENT_METHODS[method.underscore]
        end
      end

      def add_creditcard(params, creditcard_or_vault, options)
        params[:Parcelas] = options[:installments] || 1

        if creditcard_or_vault.is_a?(String)
          params[:Instituicao] = CARD_BRAND[creditcard_or_vault.underscore]
          params[:CartaoCredito] =  {
              :Cofre => options[:vault_id],
              :CodigoSeguranca => options[:verification_value]
          }
        else
          params[:Instituicao] =  CARD_BRAND[creditcard_or_vault.brand]
          params[:CartaoCredito] =  {
              :Numero =>          creditcard_or_vault.number,
              :Expiracao =>       "#{format(creditcard_or_vault.month,:two_digits)}/#{format(creditcard_or_vault.year, :two_digits)}",
              :CodigoSeguranca => creditcard_or_vault.verification_value,
              :Portador => {
                  :Nome =>           creditcard_or_vault.name,
                  :Telefone =>       options[:phone],
                  :Identidade =>     options[:identity_document],
                  :DataNascimento => options[:birthday]
              }
          }
        end
      end

      def add_customer_data(xml, customer)
        xml.tag! 'Nome',      customer[:name]
        xml.tag! 'Email',     customer[:email]
        xml.tag! 'IdPagador', customer[:id]
      end

      def add_address(xml, address)
        xml.tag! 'EnderecoCobranca' do
          xml.tag! 'Logradouro',   address[:address1]
          xml.tag! 'Complemento',  address[:address2]
          xml.tag! 'Numero',       address[:number]
          xml.tag! 'Bairro',       address[:neighborhood]
          xml.tag! 'Cidade',       address[:city]
          xml.tag! 'Estado',       address[:state]
          xml.tag! 'CEP',          address[:zip]
          xml.tag! 'Pais',         address[:country] || 'BRA'
          xml.tag! 'TelefoneFixo', address[:phone]
        end
      end

      def add_commissions(xml, options)
        xml.tag! 'Comissoes' do
          options.each do |commission|
            xml.tag! 'Comissionamento' do
              xml.tag! 'Comissionado' do
                xml.tag! 'LoginMoIP', commission[:commissioned]
              end
              xml.tag! 'Razao',           commission[:reason]
              xml.tag! 'ValorFixo',       amount(commission[:value]) unless commission[:value].blank?
              xml.tag! 'ValorPercentual', commission[:percentage].to_f unless commission[:percentage].blank?
            end
          end
        end
      end

      def add_installments_options(xml, options)
        xml.tag! 'Parcelamentos' do
          options.each do |installment|
            xml.tag! 'Parcelamento' do
              xml.tag! 'MinimoParcelas', installment[:min]
              xml.tag! 'MaximoParcelas', installment[:max]
              xml.tag! 'Recebimento',    installment[:receive_mode] || 'AVista'
              xml.tag! 'Juros',          installment[:fee]           unless installment[:fee].blank?
              xml.tag! 'Repassar',       installment[:forward_taxes] unless installment[:forward_taxes].blank?
            end
          end
        end
      end

      def add_receiver(xml, receiver)
        xml.tag! 'Recebedor' do
          xml.tag! 'LoginMoIP', receiver[:login]
          xml.tag! 'Apelido',   receiver[:nickname]
        end
      end

      def add_payment_slip_data(xml, options)
        xml.tag! 'Boleto' do
          xml.tag! 'URLLogo',         options[:logo_url]           unless options[:logo_url].blank?
          xml.tag! 'Instrucao1',      options[:instruction_line_1] unless options[:instruction_line_1]
          xml.tag! 'Instrucao2',      options[:instruction_line_2] unless options[:instruction_line_2]
          xml.tag! 'Instrucao3',      options[:instruction_line_3] unless options[:instruction_line_3]
          xml.tag! 'DiasExpiracao',   options[:expiration_days], tipo: options[:expiration_days_type] || 'Corridos' unless options[:expiration_days].blank?
          xml.tag! 'DataVencimento',  options[:expiration_date].to_date.strftime('%Y-%m-%dT%H:%M:%S.%L%:z')         unless options[:expiration_date].blank?
        end
      end

      def commit(method, format, url, parameters, headers = {})
        response = send("parse_#{format}", ssl_request(method, url, parameters, headers))

        Response.new(response[:status] == 'Sucesso' || response['StatusPagamento'] == 'Sucesso',
                     message_from(response),
                     response,
                     :test => test?,
                     :authorization => response[:token] || response['CodigoMoIP'])
      end

      def parse_json(body)
        JSON.parse(body.sub(/\A\?\(/, '').sub(/\)\z/, ''))
      end

      def parse_xml(body)
        xml = REXML::Document.new(body.force_encoding("ISO-8859-1").encode("UTF-8"))

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

      def build_url(action, params=nil)
        url = (test? ? self.test_url : self.live_url) + URL_ACTIONS[action]
        if params
          url << normalize_param(params)
        end
        url
      end

      def message_from(response)
        response['Mensagem'] || response[:erro] || response[:status]
      end

      def add_authentication
        { 'authorization' => basic_auth,
          'Accept'        => 'application/xml',
          'Content-Type'  => 'application/xml; charset=ISO-8859-1' }
      end

      def basic_auth
        "Basic " + Base64.strict_encode64(@options[:token].to_s + ":" + @options[:api_key].to_s).chomp
      end

      def normalize_param(hash)
        params = hash.map { |k,v| "#{k}=#{URI.encode(v.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&" }.join
        params.chop!
        params
      end

    end
  end
end