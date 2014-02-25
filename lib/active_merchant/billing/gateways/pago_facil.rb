module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PagoFacilGateway < Gateway
      self.test_url = 'https://www.pagofacil.net/st/public/Wsrtransaccion/index/format/json?'
      self.live_url = 'https://www.pagofacil.net/ws/public/Wsrtransaccion/index/format/json?'

      self.supported_countries = ['MX']
      self.default_currency = 'MXN'
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb]

      self.homepage_url = 'http://www.pagofacil.net/'
      self.display_name = 'PagoFacil'

      def initialize(options={})
        requires!(options, :branch_id, :merchant_id, :service_id)
        super
      end

      def purchase(money, credit_card, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, credit_card)
        add_address(post, options)
        add_customer_data(post, options)
        add_merchant_data(post)

        commit(post)
      end

      private

      def add_customer_data(post, options)
        post[:email] = options[:email]
        post[:celular] = options[:cellphone]
      end

      def add_address(post, options)
        address = options.fetch(:billing_address, {})
        post[:calleyNumero] = address[:address1]
        post[:colonia] = address[:address2]
        post[:municipio] = address[:city]
        post[:estado] = address[:state]
        post[:pais] = address[:country]
        post[:telefono] = address[:phone]
        post[:cp] = address[:zip]
      end

      def add_invoice(post, money, options)
        post[:monto] = amount(money)
        post[:idPedido] = options[:order_id]
        add_currency(post, money, options)
      end

      def add_currency(post, money, options)
        currency = options.fetch(:currency, currency(money))
        unless currency == self.class.default_currency
          post[:divisa] = currency
        end
      end

      def add_payment(post, credit_card)
        post[:nombre] = credit_card.first_name
        post[:apellidos] = credit_card.last_name
        post[:numeroTarjeta] = credit_card.number
        post[:cvt] = credit_card.verification_value
        post[:mesExpiracion] = sprintf("%02d", credit_card.month)
        post[:anyoExpiracion] = credit_card.year.to_s.slice(-2, 2)
      end

      def add_merchant_data(post)
        post[:idSucursal] = options.fetch(:branch_id)
        post[:idUsuario] = options.fetch(:merchant_id)
        post[:idServicio] = options.fetch(:service_id)
      end

      def parse(body)
        JSON.parse(body)["WebServices_Transacciones"]["transaccion"]
      rescue JSON::ParserError
        json_error(body)
      end

      def commit(parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(parameters)))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response["autorizado"] == "1" ||
          response["autorizado"] == true
      end

      def message_from(response)
        response["texto"]
      end

      def authorization_from(response)
        response["autorizacion"]
      end

      def post_data(parameters = {})
        {
          method: 'transaccion',
          data: parameters
        }.to_query
      end

      def json_error(response)
        {
          "texto" => 'Invalid response received from the PagoFacil API.',
          "raw_response" => response
        }
      end
    end
  end
end
