module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MercadoPagoGateway < Gateway
      self.live_url = self.test_url = 'https://api.mercadopago.com/v1'

      self.supported_countries = ['AR', 'BR', 'CL', 'CO', 'MX', 'PE', 'UY']
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'https://www.mercadopago.com/'
      self.display_name = 'Mercado Pago'
      self.money_format = :dollars

      CARD_BRAND = {
        "american_express" => "amex",
        "diners_club" => "diners"
      }

      def initialize(options={})
        requires!(options, :access_token)
        super
      end

      def purchase(money, payment, options={})
        MultiResponse.run do |r|
          r.process { commit("tokenize", "card_tokens", card_token_request(money, payment, options)) }
          options.merge!(card_brand: (CARD_BRAND[payment.brand] || payment.brand))
          options.merge!(card_token: r.authorization.split("|").first)
          r.process { commit("purchase", "payments", purchase_request(money, payment, options) ) }
        end
      end

      def authorize(money, payment, options={})
        MultiResponse.run do |r|
          r.process { commit("tokenize", "card_tokens", card_token_request(money, payment, options)) }
          options.merge!(card_brand: (CARD_BRAND[payment.brand] || payment.brand))
          options.merge!(card_token: r.authorization.split("|").first)
          r.process { commit("authorize", "payments", authorize_request(money, payment, options) ) }
        end
      end

      def capture(money, authorization, options={})
        post = {}
        authorization, _ = authorization.split("|")
        post[:capture] = true
        post[:transaction_amount] = amount(money).to_f
        commit("capture", "payments/#{authorization}", post)
      end

      def refund(money, authorization, options={})
        post = {}
        authorization, original_amount = authorization.split("|")
        post[:amount] = amount(money).to_f if original_amount && original_amount.to_f > amount(money).to_f
        commit("refund", "payments/#{authorization}/refunds", post)
      end

      def void(authorization, options={})
        authorization, _ = authorization.split("|")
        post = { status: "cancelled" }
        commit("void", "payments/#{authorization}", post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((access_token=).*?([^\s]+)), '\1[FILTERED]').
          gsub(%r((\"card_number\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"security_code\\\":\\\")\d+), '\1[FILTERED]')
      end

      private

      def card_token_request(money, payment, options = {})
        post = {}
        post[:card_number] = payment.number
        post[:security_code] = payment.verification_value
        post[:expiration_month] = payment.month
        post[:expiration_year] = payment.year
        post[:cardholder] = {
          name: payment.name,
          identification: {
            type: options[:cardholder_identification_type],
            number: options[:cardholder_identification_number]
          }
        }
        post
      end

      def purchase_request(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, options)
        add_additional_data(post, options)
        add_customer_data(post, payment, options)
        add_address(post, options)
        post[:binary_mode] = true
        post
      end

      def authorize_request(money, payment, options = {})
        post = purchase_request(money, payment, options)
        post.merge!(capture: false)
        post
      end

      def add_additional_data(post, options)
        post[:sponsor_id] = options[:sponsor_id]
        post[:additional_info] = {
          ip_address: options[:ip_address]
        }

        add_address(post, options)
        add_shipping_address(post, options)
      end

      def add_customer_data(post, payment, options)
        post[:payer] = {
          email: options[:email],
          first_name: payment.first_name,
          last_name: payment.last_name
        }
      end

      def add_address(post, options)
        if address = (options[:billing_address] || options[:address])

          post[:additional_info].merge!({
            payer: {
              address: {
                zip_code: address[:zip],
                street_name: "#{address[:address1]} #{address[:address2]}"
              }
            }
          })
        end
      end

      def add_shipping_address(post, options)
        if address = options[:shipping_address]

          post[:additional_info].merge!({
            shipments: {
              receiver_address: {
                zip_code: address[:zip],
                street_name: "#{address[:address1]} #{address[:address2]}"
              }
            }
          })
        end
      end

      def split_street_address(address1)
        street_number = address1.split(" ").first

        if street_name = address1.split(" ")[1..-1]
          street_name = street_name.join(" ")
        else
          nil
        end

        [street_number, street_name]
      end

      def add_invoice(post, money, options)
        post[:transaction_amount] = amount(money).to_f
        post[:description] = options[:description]
        post[:installments] = options[:installments] ? options[:installments].to_i : 1
        post[:statement_descriptor] = options[:statement_descriptor] if options[:statement_descriptor]
        post[:external_reference] = options[:order_id] || SecureRandom.hex(16)
      end

      def add_payment(post, options)
        post[:token] = options[:card_token]
        post[:payment_method_id] = options[:card_brand]
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, path, parameters)
        if ["capture", "void"].include?(action)
          response = parse(ssl_request(:put, url(path), post_data(parameters), headers))
        else
          response = parse(ssl_post(url(path), post_data(parameters), headers))
        end

        Response.new(
          success_from(action, response),
          message_from(response),
          response,
          authorization: authorization_from(response, parameters),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def success_from(action, response)
        if action == "refund"
          response["error"].nil?
        else
          ["active", "approved", "authorized", "cancelled"].include?(response["status"])
        end
      end

      def message_from(response)
        (response["status_detail"]) || (response["message"])
      end

      def authorization_from(response, params)
        [response["id"], params[:transaction_amount]].join("|")
      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def error_code_from(action, response)
        unless success_from(action, response)
          if cause = response["cause"]
            cause.empty? ? nil : cause.first["code"]
          else
            response["status"]
          end
        end
      end

      def url(action)
        full_url = (test? ? test_url : live_url)
        full_url + "/#{action}?access_token=#{@options[:access_token]}"
      end

      def headers
        {
          "Content-Type" => "application/json"
        }
      end

      def handle_response(response)
        case response.code.to_i
        when 200..499
          response.body
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
