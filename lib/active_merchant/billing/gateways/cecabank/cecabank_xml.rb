require 'active_merchant/billing/gateways/cecabank/cecabank_common'

module ActiveMerchant
  module Billing
    class CecabankXmlGateway < Gateway
      include CecabankCommon

      self.test_url = 'https://tpv.ceca.es'
      self.live_url = 'https://pgw.ceca.es'

      #### CECA's MAGIC NUMBERS
      CECA_NOTIFICATIONS_URL = 'NONE'
      CECA_DECIMALS = '2'
      CECA_MODE = 'SSL'
      CECA_UI_LESS_LANGUAGE = 'XML'
      CECA_UI_LESS_LANGUAGE_REFUND = '1'
      CECA_UI_LESS_REFUND_PAGE = 'anulacion_xml'
      CECA_ACTION_REFUND   = 'anulaciones/anularParcial' # use partial refund's URL to avoid time frame limitations and decision logic on client side
      CECA_ACTION_PURCHASE = 'tpv/compra'

      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      #
      # ==== Options
      #
      # * <tt>:order_id</tt>    -- order_id passed used purchase. (REQUIRED)
      # * <tt>:currency</tt>    -- currency. Supported: EUR, USD, GBP.
      # * <tt>:description</tt> -- description to be pased to the gateway.
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        post = { 'Descripcion' => options[:description],
                'Num_operacion' => options[:order_id],
                'Idioma' => CECA_UI_LESS_LANGUAGE,
                'Pago_soportado' => CECA_MODE,
                'URL_OK' => CECA_NOTIFICATIONS_URL,
                'URL_NOK' => CECA_NOTIFICATIONS_URL,
                'Importe' => amount(money),
                'TipoMoneda' => CECA_CURRENCIES_DICTIONARY[options[:currency] || currency(money)] }

        add_creditcard(post, creditcard)

        commit(CECA_ACTION_PURCHASE, post)
      end

      # Refund a transaction.
      #
      # This transaction indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>identification</tt> -- The reference given from the gateway on purchase (reference, not operation).
      # * <tt>options</tt> -- A hash of parameters.
      def refund(money, identification, options = {})
        reference, order_id = split_authorization(identification)

        post = { 'Referencia' => reference,
                'Num_operacion' => order_id,
                'Idioma' => CECA_UI_LESS_LANGUAGE_REFUND,
                'Pagina' => CECA_UI_LESS_REFUND_PAGE,
                'Importe' => amount(money),
                'TipoMoneda' => CECA_CURRENCIES_DICTIONARY[options[:currency] || currency(money)] }

        commit(CECA_ACTION_REFUND, post)
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((&?pan=)[^&]*)i, '\1[FILTERED]').
          gsub(%r((&?cvv2=)[^&]*)i, '\1[FILTERED]')
      end

      private

      def add_creditcard(post, creditcard)
        post['PAN'] = creditcard.number
        post['Caducidad'] = expdate(creditcard)
        post['CVV2'] = creditcard.verification_value
        post['Pago_elegido'] = CECA_MODE
      end

      def expdate(creditcard)
        "#{format(creditcard.year, :four_digits)}#{format(creditcard.month, :two_digits)}"
      end

      def parse(body)
        response = {}

        root = REXML::Document.new(body).root

        response[:success] = (root.attributes['valor'] == 'OK')
        response[:date] = root.attributes['fecha']
        response[:operation_number] = root.attributes['numeroOperacion']
        response[:message] = root.attributes['valor']

        if root.elements['OPERACION']
          response[:operation_type] = root.elements['OPERACION'].attributes['tipo']
          response[:amount] = root.elements['OPERACION/importe'].text.strip
        end

        response[:description] = root.elements['OPERACION/descripcion'].text if root.elements['OPERACION/descripcion']
        response[:authorization_number] = root.elements['OPERACION/numeroAutorizacion'].text if root.elements['OPERACION/numeroAutorizacion']
        response[:reference] = root.elements['OPERACION/referencia'].text if root.elements['OPERACION/referencia']
        response[:pan] = root.elements['OPERACION/pan'].text if root.elements['OPERACION/pan']

        if root.elements['ERROR']
          response[:error_code] = root.elements['ERROR/codigo'].text
          response[:error_message] = root.elements['ERROR/descripcion'].text
        elsif root.elements['OPERACION'].attributes['numeroOperacion'] == '000'
          response[:authorization] = root.elements['OPERACION/numeroAutorizacion'].text if root.elements['OPERACION/numeroAutorizacion']
        else
          response[:authorization] = root.attributes['numeroOperacion']
        end

        return response
      rescue REXML::ParseException => e
        response[:success] = false
        response[:message] = 'Unable to parse the response.'
        response[:error_message] = e.message
        response
      end

      def commit(action, parameters)
        parameters.merge!(
          'Cifrado' => CECA_ENCRIPTION,
          'Firma' => generate_signature(action, parameters),
          'Exponente' => CECA_DECIMALS,
          'MerchantID' => options[:merchant_id],
          'AcquirerBIN' => options[:acquirer_bin],
          'TerminalID' => options[:terminal_id]
        )
        url = (test? ? self.test_url : self.live_url) + "/tpvweb/#{action}.action"
        xml = ssl_post("#{url}?", post_data(parameters))
        response = parse(xml)
        Response.new(
          response[:success],
          message_from(response),
          response,
          test: test?,
          authorization: build_authorization(response),
          error_code: response[:error_code]
        )
      end

      def message_from(response)
        if response[:message] == 'ERROR' && response[:error_message]
          response[:error_message]
        elsif response[:error_message]
          "#{response[:message]} #{response[:error_message]}"
        else
          response[:message]
        end
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value.blank?

          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}.#{k}"] = v unless v.blank?
            end
            post_data(h)
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join('&')
      end

      def build_authorization(response)
        [response[:reference], response[:authorization]].join('|')
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def generate_signature(action, parameters)
        signature_fields =
          case action
          when CECA_ACTION_REFUND
            options[:signature_key].to_s +
            options[:merchant_id].to_s +
            options[:acquirer_bin].to_s +
            options[:terminal_id].to_s +
            parameters['Num_operacion'].to_s +
            parameters['Importe'].to_s +
            parameters['TipoMoneda'].to_s +
            CECA_DECIMALS +
            parameters['Referencia'].to_s +
            CECA_ENCRIPTION
          else
            options[:signature_key].to_s +
            options[:merchant_id].to_s +
            options[:acquirer_bin].to_s +
            options[:terminal_id].to_s +
            parameters['Num_operacion'].to_s +
            parameters['Importe'].to_s +
            parameters['TipoMoneda'].to_s +
            CECA_DECIMALS +
            CECA_ENCRIPTION +
            CECA_NOTIFICATIONS_URL +
            CECA_NOTIFICATIONS_URL
          end
        Digest::SHA2.hexdigest(signature_fields)
      end
    end
  end
end
