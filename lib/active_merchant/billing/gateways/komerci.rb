module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class KomerciGateway < Gateway

      self.test_url = 'https://ecommerce.redecard.com.br/pos_virtual/wskomerci/cap_teste.asmx'
      self.live_url = 'https://ecommerce.redecard.com.br/pos_virtual/wskomerci/cap.asmx'

      self.supported_countries = %w(BR)
      self.supported_cardtypes = %i(visa master diners_club)
      self.supported_banks = %i()
      self.supported_boletos = %i()
      self.homepage_url = 'http://www.userede.com.br/pt-BR/Paginas/default.aspx'
      self.display_fullname = 'Rede'
      self.display_name = 'Rede'
      self.display_logo = 'https://cdn.edools.com/assets/images/gateways/Rede.png'
      self.default_currency = 'BRL'

      SALE_TYPES = {
        spot_sale: '04',
        issuing_instalments: '06',
        establishment_instalments: '08'
      }

      def initialize(options={})
        requires!(options, :username, :password, :code)
        super
      end

      def purchase(money, credit_card, options={})
        post = {}

        set_sale_type(options)

        # add_user_account(post)
        add_affiliate(post, options)
        add_invoice(post, money, options)
        add_payment_value(post, money, options)
        add_credit_card(post, credit_card)
        add_transacao(post, options)
        add_authorize_empty_params(post)
        commit('GetAuthorized', post)
      end

      # Besides the authorization, we need the 'numcv' from the authorize
      # response to be able to capture the transaction.
      #
      def prepare_capture_options(r, options)
        {
          sale_number: r.params['numcv'],
          sale_type: SALE_TYPES[options[:sale_type]] || '04'
        }.merge(options)
      end

      def authorize(money, credit_card, options={})
        post = {}
        add_affiliate(post, options)
        add_invoice(post, money, options)
        add_payment_value(post, money, options)
        add_credit_card(post, credit_card)
        add_authorize_empty_params(post)

        commit('GetAuthorized', post)
      end

      def capture(money, authorization, options={})
        requires!(options, :sale_number)
        post = {}

        add_affiliate(post, options)
        add_authorization(post, authorization, options)
        add_payment_value(post, money, options)
        add_user_account(post)
        add_date(post, options)
        add_authorize_empty_params(post)
        add_transaction_type(post, options)

        commit('ConfPreAuthorization', post)
      end

      def refund(money, authorization, options={})
        post = {}

        add_affiliate(post, options)
        add_payment_value(post, money, options)
        add_authorization(post, authorization, options)
        add_authorize_empty_params(post)
        add_user_account(post)
        add_date(post, options)

        commit('VoidConfPreAuthorization', post)

        commit('refund', post)
      end

      def void(authorization, options={})
        requires!(options, :money)
        post = {}

        set_sale_type(options)

        add_affiliate(post, options)
        add_payment_value(post, options[:money], options)
        add_authorization(post, authorization, options)
        add_authorize_empty_params(post)
        add_user_account(post)
        add_date(post, options)

        commit('VoidPreAuthorization', post)
      end

      def details(token)
        Response.new(false, 'Not Supported', {}, test: test?)
      end

      private

      def set_sale_type(options)
        options[:sale_type] = if options[:credit_card][:installments] <= 1
                                :spot_sale
                              else
                                :establishment_instalments
                              end
      end

      def add_transaction_type(post, options)
        post[:transorig] = options[:sale_type]
      end

      def add_user_account(post)
        post[:usr] = @options[:username]
        post[:pwd] = @options[:password]
      end

      def add_date(post, options)
        post[:data] = options[:date] || Date.today.strftime("%Y%m%d")
      end

      def add_authorization(post, authorization, options)
        post[:numautor] = authorization
        post[:numcv] = options[:sale_number]
      end

      def add_affiliate(post, options)
        post[:filiacao] = @options[:code]
        post[:distribuidor] = @options.fetch(:distributor, nil)
      end

      def add_payment_value(post, money, options)
        post[:total] = amount(money)
        post[:parcelas] = '00'
        return unless options[:credit_card][:installments] > 1
        post[:parcelas] =  "%02d" % options[:credit_card][:installments]
      end

      def add_invoice(post, money, options)
        post[:transacao] = '73'
        post[:numpedido] = options[:transaction_id]
      end

      def add_credit_card(post, credit_card)
        post[:nrcartao] = credit_card.number
        post[:cvc2] = credit_card.verification_value
        post[:mes] = credit_card.month < 10 ? "0#{credit_card.month}" : credit_card.month.to_s
        post[:ano] = credit_card.year.to_s.slice(2..4)
        post[:portador] = [credit_card.first_name, credit_card.last_name].join(' ')
      end

      def add_transacao(post, options)
        post[:transacao] = SALE_TYPES[options[:sale_type]] || '04'
      end

      # All the request parameters are required anf if not used should be sent
      # empty.
      #
      def add_authorize_empty_params(post)
        post[:iata] = nil
        post[:concentrador] = nil
        post[:taxaembarque] = nil
        post[:entrada] = nil
        post[:numdoc1] = nil
        post[:numdoc2] = nil
        post[:numdoc3] = nil
        post[:numdoc4] = nil
        post[:pax1] = nil
        post[:pax2] = nil
        post[:pax3] = nil
        post[:pax4] = nil
        post[:conftxn] = 'S'
        post[:add_data] = nil
      end

      def commit(action, parameters)
        url = build_commit_url(action)
        data = post_data(action, parameters)
        response = parse(ssl_post(url, data))

        Response.new(
          success_from(response, action),
          message_from(response),
          response,
          authorization: authorization_from(response),
          payment_action: status_action_from(response, action),
          test: test?
        )
      end

      def build_commit_url(action)
        url = (test? ? "#{test_url}/#{action}Tst" : "#{live_url}/#{action}")
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

      def success_from(response, action)
        if action == 'GetAuthorized'
          response[:codret] == '0' and response[:confcodret] == '0' and response[:numcv].present?
        else
          response[:codret] == '0'
        end
      end

      def message_from(response)
        response[:msgret]
      end

      def authorization_from(response)
        response[:numautor]
      end

      def status_action_from(response, action)
        return :confirm if action == 'GetAuthorized' && response[:codret] == '0' && response[:confcodret] == '0' && response[:numcv].present?
        return :confirm if response[:codret] == '0'
        return :fail
      end

      def post_data(action, parameters = {})
        data = parameters.map { |k,v| "&#{k}=#{URI.encode(v.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}" }.join
        data[0] = ''
        data
      end
    end
  end
end
