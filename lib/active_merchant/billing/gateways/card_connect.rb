module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardConnectGateway < Gateway
      self.test_url = 'https://fts.cardconnect.com:6443/cardconnect/rest/'
      self.live_url = 'https://fts.cardconnect.com:8443/cardconnect/rest/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://cardconnect.com/'
      self.display_name = 'Card Connect'

      STANDARD_ERROR_CODE_MAPPING = {
        '11' => STANDARD_ERROR_CODE[:card_declined],
        '12' => STANDARD_ERROR_CODE[:incorrect_number],
        '13' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '14' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '15' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '16' => STANDARD_ERROR_CODE[:expired_card],
        '17' => STANDARD_ERROR_CODE[:incorrect_zip],
        '21' => STANDARD_ERROR_CODE[:config_error],
        '22' => STANDARD_ERROR_CODE[:config_error],
        '23' => STANDARD_ERROR_CODE[:config_error],
        '24' => STANDARD_ERROR_CODE[:processing_error],
        '25' => STANDARD_ERROR_CODE[:processing_error],
        '27' => STANDARD_ERROR_CODE[:processing_error],
        '28' => STANDARD_ERROR_CODE[:processing_error],
        '29' => STANDARD_ERROR_CODE[:processing_error],
        '31' => STANDARD_ERROR_CODE[:processing_error],
        '32' => STANDARD_ERROR_CODE[:processing_error],
        '33' => STANDARD_ERROR_CODE[:card_declined],
        '34' => STANDARD_ERROR_CODE[:card_declined],
        '35' => STANDARD_ERROR_CODE[:incorrect_zip],
        '36' => STANDARD_ERROR_CODE[:processing_error],
        '37' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '41' => STANDARD_ERROR_CODE[:processing_error],
        '42' => STANDARD_ERROR_CODE[:processing_error],
        '43' => STANDARD_ERROR_CODE[:processing_error],
        '44' => STANDARD_ERROR_CODE[:config_error],
        '61' => STANDARD_ERROR_CODE[:processing_error],
        '62' => STANDARD_ERROR_CODE[:processing_error],
        '63' => STANDARD_ERROR_CODE[:processing_error],
        '64' => STANDARD_ERROR_CODE[:config_error],
        '65' => STANDARD_ERROR_CODE[:processing_error],
        '66' => STANDARD_ERROR_CODE[:processing_error],
        '91' => STANDARD_ERROR_CODE[:processing_error],
        '92' => STANDARD_ERROR_CODE[:processing_error],
        '93' => STANDARD_ERROR_CODE[:processing_error],
        '94' => STANDARD_ERROR_CODE[:processing_error],
        '95' => STANDARD_ERROR_CODE[:config_error],
        '96' => STANDARD_ERROR_CODE[:processing_error],
        'NU' => STANDARD_ERROR_CODE[:card_declined],
        'N3' => STANDARD_ERROR_CODE[:card_declined],
        'NJ' => STANDARD_ERROR_CODE[:card_declined],
        '51' => STANDARD_ERROR_CODE[:card_declined],
        'C2' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '54' => STANDARD_ERROR_CODE[:expired_card],
        '05' => STANDARD_ERROR_CODE[:card_declined],
        '03' => STANDARD_ERROR_CODE[:config_error],
        '60' => STANDARD_ERROR_CODE[:pickup_card]
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :username, :password)
        require_valid_domain!(options, :domain)
        super
      end

      def require_valid_domain!(options, param)
        if options[param]
          raise ArgumentError.new('not a valid cardconnect domain') unless /https:\/\/\D*cardconnect.com/ =~ options[param]
        end
      end

      def purchase(money, payment, options = {})
        if options[:po_number]
          MultiResponse.run do |r|
            r.process { authorize(money, payment, options) }
            r.process { capture(money, r.authorization, options) }
          end
        else
          post = {}
          add_invoice(post, options)
          add_money(post, money)
          add_payment(post, payment)
          add_currency(post, money, options)
          add_address(post, options)
          add_customer_data(post, options)
          add_3DS(post, options)
          add_additional_data(post, options)
          post[:capture] = 'Y'
          commit('auth', post)
        end
      end

      def authorize(money, payment, options = {})
        post = {}
        add_money(post, money)
        add_currency(post, money, options)
        add_invoice(post, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        add_3DS(post, options)
        add_additional_data(post, options)
        commit('auth', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_money(post, money)
        add_reference(post, authorization)
        add_additional_data(post, options)
        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_money(post, money)
        add_reference(post, authorization)
        commit('refund', post)
      end

      def void(authorization, options = {})
        post = {}
        add_reference(post, authorization)
        commit('void', post)
      end

      def verify(credit_card, options = {})
        authorize(0, credit_card, options)
      end

      def store(payment, options = {})
        post = {}
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        commit('profile', post)
      end

      def unstore(authorization, options = {})
        account_id, profile_id = authorization.split('|')
        commit('profile', {},
          verb: :delete,
          path: "/#{profile_id}/#{account_id}/#{@options[:merchant_id]}")
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("cvv2\\":\\")\d*), '\1[FILTERED]').
          gsub(%r(("merchid\\":\\")\d*), '\1[FILTERED]').
          gsub(%r((&?"account\\":\\")\d*), '\1[FILTERED]').
          gsub(%r((&?"token\\":\\")\d*), '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:email] = options[:email] if options[:email]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:address] = address[:address1] if address[:address1]
          post[:address].concat(" #{address[:address2]}") if address[:address2]
          post[:city] = address[:city] if address[:city]
          post[:region] = address[:state] if address[:state]
          post[:country] = address[:country] if address[:country]
          post[:postal] = address[:zip] if address[:zip]
          post[:phone] = address[:phone] if address[:phone]
        end
      end

      def add_money(post, money)
        post[:amount] = amount(money)
      end

      def add_currency(post, money, options)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_invoice(post, options)
        post[:orderid] = options[:order_id]
        post[:ecomind] = (options[:recurring] ? 'R' : 'E')
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          account_id, profile_id = payment.split('|')
          post[:profile] = profile_id
          post[:acctid] = account_id
        else
          post[:name] = payment.name
          if card_brand(payment) == 'check'
            add_echeck(post, payment)
          else
            post[:account] = payment.number
            post[:expiry] = expdate(payment)
            post[:cvv2] = payment.verification_value
          end
        end
      end

      def add_echeck(post, payment)
        post[:accttype] = 'ECHK'
        post[:account] = payment.account_number
        post[:bankaba] = payment.routing_number
      end

      def add_reference(post, authorization)
        post[:retref] = authorization
      end

      def add_additional_data(post, options)
        post[:ponumber] = options[:po_number]
        post[:taxamnt] = options[:tax_amount] if options[:tax_amount]
        post[:frtamnt] = options[:freight_amount] if options[:freight_amount]
        post[:dutyamnt] = options[:duty_amount] if options[:duty_amount]
        post[:orderdate] = options[:order_date] if options[:order_date]
        post[:shipfromzip] = options[:ship_from_zip] if options[:ship_from_zip]
        if (shipping_address = options[:shipping_address])
          post[:shiptozip] = shipping_address[:zip]
          post[:shiptocountry] = shipping_address[:country]
        end
        if options[:items]
          post[:items] = options[:items].map do |item|
            updated = {}
            item.each_pair do |k, v|
              updated.merge!(k.to_s.gsub(/_/, '') => v)
            end
            updated
          end
        end
        post[:userfields] = options[:user_fields] if options[:user_fields]
      end

      def add_3DS(post, options)
        post[:secureflag] = options[:secure_flag] if options[:secure_flag]
        post[:securevalue] = options[:secure_value] if options[:secure_value]
        post[:securexid] = options[:secure_xid] if options[:secure_xid]
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.strict_encode64("#{@options[:username]}:#{@options[:password]}"),
          'Content-Type' => 'application/json'
        }
      end

      def expdate(credit_card)
        "#{format(credit_card.month, :two_digits)}#{format(credit_card.year, :two_digits)}"
      end

      def parse(body)
        JSON.parse(body)
      end

      def url(action, path)
        if test?
          test_url + action + path
        else
          (@options[:domain] || live_url) + action + path
        end
      end

      def commit(action, parameters, verb: :put, path: '')
        parameters[:frontendid] = application_id
        parameters[:merchid] = @options[:merchant_id]
        url = url(action, path)
        response = parse(ssl_request(verb, url, post_data(parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['avsresp']),
          cvv_result: CVVResult.new(response['cvvresp']),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ResponseError => e
        return Response.new(false, 'Unable to authenticate.  Please check your credentials.', {}, test: test?) if e.response.code == '401'

        raise
      end

      def success_from(response)
        response['respstat'] == 'A'
      end

      def message_from(response)
        response['setlstat'] ? "#{response['resptext']} #{response['setlstat']}" : response['resptext']
      end

      def authorization_from(response)
        if response['profileid']
          "#{response['acctid']}|#{response['profileid']}"
        else
          response['retref']
        end
      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response['respcode']] unless success_from(response)
      end
    end
  end
end
