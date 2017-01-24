module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module MoipCore #:nodoc:
      URL_ACTIONS = {
          'authenticate'  => '/ws/alpha/EnviarInstrucao/Unica',
          'pay'           => '/rest/pagamento?callback=?',
          'query'         => '/ws/alpha/ConsultarInstrucao/'
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
          'santander'        => 'DebitoBancario',
          'bank_transfer'    => 'DebitoBancario',
          'boleto'           => 'BoletoBancario',
          'visa'             => 'CartaoCredito',
          'master'           => 'CartaoCredito',
          'diners_club'      => 'CartaoCredito',
          'american_express' => 'CartaoCredito'
      }

      PAYMENT_ACTIONS = {
        'Autorizado'     => :authorize,
        'Iniciado'       => :initiate,
        'BoletoImpresso' => :wait_boleto,
        'Concluido'      => :confirm,
        'Cancelado'      => :cancel,
        'EmAnalise'      => :wait_analysis,
        'Estornado'      => :reverse,
        'Reembolsado'    => :refund
      }

      def initialize(options = {})
        requires!(options, :username, :password)
        super
      end

      private

      def build_authenticate_request(money, options)
        options[:extras] ||= {}

        xml = Builder::XmlMarkup.new
        xml.tag! 'EnviarInstrucao' do
          xml.tag! 'InstrucaoUnica', TipoValidacao: 'Transparente' do

            xml.tag! 'IdProprio', options[:transaction_id]
            xml.tag! 'Razao',     options[:reason]

            xml.tag! 'Valores' do
              currency = options[:extras][:currency] || default_currency
              xml.tag! 'Valor',     amount(money),                moeda: currency
              xml.tag! 'Acrescimo', amount(options[:extras][:additional]), moeda: currency unless options[:extras][:additional].blank?
              xml.tag! 'Deducao',   amount(options[:extras][:discount]),   moeda: currency unless options[:extras][:discount].blank?
            end

            xml.tag! 'Pagador' do
              add_customer_data(xml, options[:customer])
              add_address(xml, options[:address])
            end

            add_commissions(xml, options[:extras][:commissions])        unless options[:extras][:commissions].blank?
            add_installments_options(xml, options[:installments_info])  unless options[:installments_info].blank?
            add_receiver(xml, options[:extras][:receiver])              unless options[:extras][:receiver].blank?
            add_payment_slip_data(xml, options[:boleto])                unless options[:boleto].blank?

            xml.tag! 'URLNotificacao', options[:extras][:notification_url] unless options[:extras][:notification_url].blank?
            xml.tag! 'URLRetorno', options[:extras][:return_url]           unless options[:extras][:return_url].blank?

          end
        end
        xml.target!
      end

      def build_pay_params(authorization, options)
        params = {
            :pagamentoWidget => {
                :token => authorization,
                :referer => options[:referer],
                :dadosPagamento => {
                    :Forma => payment_methods(options[:payment_method])
                }
            }
        }

        case params[:pagamentoWidget][:dadosPagamento][:Forma]
          when 'CartaoCredito'
            requires!(options, :credit_card, :customer)
            add_creditcard(params[:pagamentoWidget][:dadosPagamento], options[:payment_method], options[:credit_card], options[:customer])
          when 'DebitoBancario'
            params[:pagamentoWidget][:dadosPagamento][:Instituicao] = options[:bank_transfer][:institution].classify
        end

        {
            :pagamentoWidget => params.to_json
        }
      end

      def payment_methods(method)
        if method.is_a?(CreditCard)
          'CartaoCredito'
        else
          PAYMENT_METHODS[method.to_s.underscore]
        end
      end

      def add_creditcard(params, creditcard_or_vault, cc_options, customer)
        params[:Parcelas] = cc_options[:installments] || 1

        if creditcard_or_vault.is_a?(String)
          params[:Instituicao] = CARD_BRAND[creditcard_or_vault.underscore]
          params[:CartaoCredito] =  {
              :Cofre => options[:vault_id],
              :CodigoSeguranca => options[:cvv]
          }
        else
          params[:Instituicao] =  CARD_BRAND[creditcard_or_vault.brand]
          params[:CartaoCredito] =  {
              :Numero =>          creditcard_or_vault.number,
              :Expiracao =>       "#{format(creditcard_or_vault.month, :two_digits)}/#{format(creditcard_or_vault.year, :two_digits)}",
              :CodigoSeguranca => creditcard_or_vault.verification_value,
              :Portador => {
                  :Nome =>           creditcard_or_vault.name,
                  :Telefone =>       customer[:phone],
                  :Identidade =>     customer[:legal_identifier],
                  :DataNascimento => customer[:born_at]
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
          xml.tag! 'Logradouro',   address[:street]
          xml.tag! 'Complemento',  address[:complement]
          xml.tag! 'Numero',       address[:number]
          xml.tag! 'Bairro',       address[:district]
          xml.tag! 'Cidade',       address[:city]
          xml.tag! 'Estado',       address[:state]
          xml.tag! 'CEP',          address[:zip_code]
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
        expiration_days_type = if options[:expiration_days_type] == 'business_days'
                                 'Uteis'
                               else
                                 'Corridos'
                               end
        xml.tag! 'Boleto' do
          xml.tag! 'URLLogo',         options[:logo_url]           unless options[:logo_url].blank?
          xml.tag! 'Instrucao1',      options[:instruction_line_1] unless options[:instruction_line_1].blank?
          xml.tag! 'Instrucao2',      options[:instruction_line_2] unless options[:instruction_line_2].blank?
          xml.tag! 'Instrucao3',      options[:instruction_line_3] unless options[:instruction_line_3].blank?
          xml.tag! 'DiasExpiracao',   options[:expiration_days], tipo: expiration_days_type unless options[:expiration_days].blank?
          xml.tag! 'DataVencimento',  options[:expiration_date].to_date.strftime('%Y-%m-%dT%H:%M:%S.%L%:z') unless options[:expiration_date].blank?
        end
      end

      def commit(method, format, url, parameters, headers = {}, payment_method = nil, authorization = nil)
        response = send("parse_#{format}", ssl_request(method, url, parameters, headers))

        if response['ConsultarTokenResponse'] && response['ConsultarTokenResponse']['RespostaConsultar'] &&
          response['ConsultarTokenResponse']['RespostaConsultar'].keys == ['ID', 'Status']

          Response.new(success?(response), {}, {}, test: test?)
        else
          params = params_from(response)

          Response.new(success?(response), message_from(response), params, test: test?,
            authorization: authorization || authorization_from(response),
            payment_action: status_action_from(response, payment_method),
            external_url: params[:url],
            gateway_transaction_code: gateway_transaction_code_from(response))
        end
      end

      def parse_json(body)
        JSON.parse(body.sub(/\A\?\(/, '').sub(/\)\z/, ''))
      end

      def parse_xml(body)
        @xml = REXML::Document.new(body.force_encoding("windows-1252").encode('windows-1254').encode('utf-8'))
        Hash.from_xml(body.force_encoding("windows-1252").encode('windows-1254').encode('utf-8'))
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
        url << normalize_param(params) if params && params.is_a?(Hash)
        url << params if params && params.is_a?(String)
        url
      end

      def normalize_param(hash)
        if hash.is_a? Hash
          hash.map { |k,v| "&#{k}=#{URI.encode(v.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}" }.join
        elsif hash.is_a? String
          hash
        end
      end

      def success?(response)
        if @query
          response['ConsultarTokenResponse']['RespostaConsultar']['Status'] == 'Sucesso'
        else
          if response.has_key?('EnviarInstrucaoUnicaResponse')
            return response['EnviarInstrucaoUnicaResponse']['Resposta']['Status'] == 'Sucesso'
          elsif response.has_key?('StatusPagamento')
            return response['StatusPagamento'] == 'Sucesso'
          end
        end
      end

      def authorization_from(response)
        if response.has_key?('EnviarInstrucaoUnicaResponse')
          response['EnviarInstrucaoUnicaResponse']['Resposta']['Token']
        else
          
          if @query
            payments = response['ConsultarTokenResponse']['RespostaConsultar']['Autorizacao']['Pagamento']

            payments.is_a?(Array) ? payments.last['CodigoMoIP'] : payments['CodigoMoIP']
          else
            response['CodigoMoIP']
          end
        end
      end

      def gateway_transaction_code_from(response)
        if !response.has_key?('EnviarInstrucaoUnicaResponse')          
          if @query
            payments = response['ConsultarTokenResponse']['RespostaConsultar']['Autorizacao']['Pagamento']

            payments.is_a?(Array) ? payments.last['CodigoMoIP'] : payments['CodigoMoIP']
          else
            response['CodigoMoIP']
          end
        else
          nil
        end
      end

      def message_from(response)
        if @query
          message = {}
          status  = REXML::XPath.each(@xml, '//Status[@Tipo]').first

          code        = status.attribute('Tipo').value.try(:strip)
          description = status.attribute('Classificacao').value.try(:strip) if code == '5'

          message[:description] = description
          message[:code]        = code

          payments         = response['ConsultarTokenResponse']['RespostaConsultar']['Autorizacao']['Pagamento']
          message[:status] = payments.is_a?(Array) ? payments.last['Status'].try(:strip) : payments['Status'].try(:strip)

          message
        else
          response['Mensagem'] || response[:erro] || response[:status] || (response['EnviarInstrucaoUnicaResponse'] && response['EnviarInstrucaoUnicaResponse']['Resposta']['Erro'])
        end
      end

      def params_from(response)
        if response.has_key?('EnviarInstrucaoUnicaResponse')
          return response.merge(url: "#{test? ? self.test_url : self.live_url}/Instrucao.do?token=#{response['EnviarInstrucaoUnicaResponse']['Resposta']['Token']}")
        else
          return response
        end
      end

      def status_action_from(response, payment_method)
        status = if response['Status']
                    response['Status']
                 elsif @query
                    payments = response['ConsultarTokenResponse']['RespostaConsultar']['Autorizacao']['Pagamento']

                    payments.is_a?(Array) ? payments.last['Status'].try(:strip) : payments['Status'].try(:strip)
                 end

        if status
          PAYMENT_ACTIONS[status]
        elsif payment_method == :boleto
          :wait_boleto
        elsif payment_method == :bank_transfer
          :initiate
        end
      end

      def add_authentication
        {
          'authorization' => basic_auth,
          'Accept'        => 'application/xml',
          'Content-Type'  => 'application/xml; charset=ISO-8859-1'
        }
      end

      def basic_auth
        "Basic " + Base64.strict_encode64(@options[:username].to_s + ":" + @options[:password].to_s).chomp
      end
    end
  end
end
