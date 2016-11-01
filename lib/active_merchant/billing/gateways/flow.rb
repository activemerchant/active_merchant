require 'active_support/core_ext/hash/slice'

begin
  require 'flowcommerce'
rescue LoadError
  raise "Could not load the flowcommerce gem. Use `gem install flowcommerce` to install it."
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FlowGateway < Gateway
      self.live_url = 'https://api.flow.io/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club, :maestro, :china_union_pay, :dankort]

      self.homepage_url = 'https://flow.io/'
      self.display_name = 'Flow.io'

      STANDARD_ERROR_CODE_MAPPING = {
        'expired' => STANDARD_ERROR_CODE[:expired_card],
        'declined' => STANDARD_ERROR_CODE[:card_declined],
        'cvv' => STANDARD_ERROR_CODE[:invalid_cvc],
        'fraud' => STANDARD_ERROR_CODE[:processing_error],
        'pending_call_bank' => STANDARD_ERROR_CODE[:call_issuer],
        'invalid_number' => STANDARD_ERROR_CODE[:invalid_number],
        'invalid_expiration' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'no_account' => STANDARD_ERROR_CODE[:incorrect_number]
      }

      AVS_CODE_TRANSLATOR = {
        'match' => 'Y',
        'no_match' => 'N',
        'unsupported' => 'E',
        'name: false, address: true, postal: false' => 'A',
        'name: false, address: false, postal: true' => 'Z',
        'name: false, address: true, postal: true' => 'H',
        'name: true, address: false, postal: false' => 'K',
        'name: true, address: true, postal: false' => 'O',
        'name: true, address: false, postal: true' => 'L',
      }

      def initialize(options={})
        requires!(options, :api_key, :organization)
        @api_key = options[:api_key]
        @organization = options[:organization]
        @client = FlowCommerce.instance(token: @api_key)

        super
      end

      def store(payment, options = {})
        post = {}
        add_credit_card(post, payment)
        if payment.respond_to?(:number)
          add_address(post, :address, options[:billing_address])
          card_form = Io::Flow::V0::Models::CardForm.new(post)
          card = @client.cards.post(@organization, card_form)
        else
          nonce_form = Io::Flow::V0::Models::CardNonceForm.new(post)
          card = @client.cards.post_nonces(@organization, nonce_form)
        end

        success = card.respond_to?(:token)
        Response.new(
          success,
          success ? "Transaction approved" : "Card store failed",
          { object: card },
        )
      end

      def purchase(money, payment, options={})
        MultiResponse.run do |r|
          r.process { authorize(money, payment, options) }
          if r.success?
            authorization = r.authorization
            r.process { capture(money, authorization, options) }
          end
        end.responses.last
      end

      def authorize(money, payment, options={})
        post = {}
        if money.nil?
          requires!(options, :order_id)
          post[:order_number] = options[:order_id]
          post.merge!(options.slice(:ip, :attributes))
          auth_form_klass = Io::Flow::V0::Models::MerchantOfRecordAuthorizationForm
        else
          add_invoice(post, money, options)
          add_address(post, :destination, options[:shipping_address])
          add_customer_data(post, options)
          auth_form_klass = Io::Flow::V0::Models::DirectAuthorizationForm
        end

        commit do
          if payment.respond_to?(:number)
            response = store(payment, options)
            unless response.success?
              return response
            end
            payment = response.params["object"].token
          end
          add_payment(post, payment)

          authorization_form = auth_form_klass.new(post)
          auth = @client.authorizations.post(@organization, authorization_form)
          success = auth.respond_to?(:result) && auth.result.status.value == "authorized"
          Response.new(
            success,
            success ? "Transaction approved" : "Your card was declined",
            { object: auth },
            authorization: auth.id,
            avs_result: AVSResult.new(code: avs_code_from_auth(auth)),
            cvv_result: CVVResult.new(cvv_code_from_auth(auth)),
            error_code: success ? nil : error_code_from(auth)
          )
        end
      end

      def capture(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        post[:authorization_id] = authorization
        capture_form = Io::Flow::V0::Models::CaptureForm.new(post)
        commit do
          capture = @client.captures.post(@organization, capture_form)
          Response.new(
            true,
            "Transaction approved",
            { object: capture },
            authorization: capture.authorization.id
          )
        end
      end

      def refund(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)
        post[:authorization_id] = authorization
        refund_form = Io::Flow::V0::Models::RefundForm.new(post)
        refund = @client.refunds.post(@organization, refund_form)

        success = true

        Response.new(
          success,
          "Transaction approved",
          { object: refund },
          authorization: refund.authorization.id,
        )
      end

      def void(authorization, options={})
        commit do
          @client.authorizations.delete_by_key(@organization, authorization)

          Response.new(
            true,
            "Transaction approved",
            {},
            authorization: authorization
          )
        end
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(options.fetch(:amount, 50), credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        false
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_credit_card(post, credit_card)
        if credit_card.respond_to?(:number)
          post[:number] = credit_card.number
          post[:expiration_month] = credit_card.month
          post[:expiration_year] = credit_card.year
          post[:name] = credit_card.name
          post[:cvv] = credit_card.verification_value if credit_card.verification_value?
        elsif credit_card.is_a?(String)
          post[:token] = credit_card
        end
      end

      def add_customer_data(post, options)
        requires!(options, :customer)
        post.merge!(options.slice(:ip, :attributes))

        if options[:customer] || options[:email]
          post[:customer] = {}
        end
        if customer = options[:customer]
          post[:customer][:name] = {}
          post[:customer][:name][:first] = customer[:first_name]
          post[:customer][:name][:last] = customer[:last_name]
        end
        post[:customer][:email] = options[:email] if options[:email]
      end

      def add_address(post, key, address)
        if address
          post[key] = {}
          post[key][:streets] = []
          post[key][:streets] << address[:address1] if address[:address1]
          post[key][:streets] << address[:address2] if address[:address2]
          post[key][:country] = address[:country] if address[:country]
          post[key][:postal] = address[:zip] if address[:zip]
          post[key][:province] = address[:state] if address[:state]
          post[key][:city] = address[:city] if address[:city]
        end
      end

      def add_invoice(post, money, options)
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency
      end

      def add_payment(post, payment)
        if payment.kind_of?(String)
          post[:token] = payment
        end
      end

      def parse(body)
        {}
      end

      def api_endpoint
        live_url + @organization + "/"
      end

      def commit(&block)
        yield
        # TODO: fetch the response here and build response object here
      rescue Io::Flow::V0::HttpClient::ServerError => e
        Response.new(
          false,
          message_from_exception(e),
          { object: e.body.present? ? e.body_json : {} }, # Need to check body before parse JSON...this will be fixed later by flow
          error_code: e.code == 422 ? e.body_json["code"] : nil
        )
        # Response.new(
        #   success_from(response),
        #   message_from(response),
        #   response,
        #   authorization: authorization_from(response),
        #   avs_result: AVSResult.new(code: response["some_avs_response_key"]),
        #   cvv_result: CVVResult.new(response["some_cvv_response_key"]),
        #   test: test?,
        #   error_code: error_code_from(response)
        # )
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def avs_code_from_auth(auth)
        return AVS_CODE_TRANSLATOR['match'] unless auth.result.avs
        avs = auth.result.avs
        code = avs.code.value
        if code == 'partial'
          code = 'name: %s, address: %s, postal: %s' % [avs.name, avs.address, avs.postal]
        end
        AVS_CODE_TRANSLATOR[code]
      end

      def cvv_code_from_auth(auth)
        decline_code = auth.result.decline_code
        if decline_code && decline_code.value == 'cvv'
          'N'
        else
          'M'
        end
      end

      def error_code_from(response)
        code = response.result.status
        decline_code = response.result.decline_code
        error_code = STANDARD_ERROR_CODE_MAPPING[decline_code.value] if decline_code
        error_code ||= STANDARD_ERROR_CODE_MAPPING[code.value]
        error_code
      end

      def message_from_exception(ex)
        if ex.code == 422
          ex.body_json["messages"].first
        else
          ex.details
        end
      end
    end
  end
end
