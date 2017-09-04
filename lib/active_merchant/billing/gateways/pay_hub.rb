module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayHubGateway < Gateway
      self.live_url = 'https://checkout.payhub.com/transaction/api'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.payhub.com/'
      self.display_name = 'PayHub'

      CVV_CODE_TRANSLATOR = {
        'M' => 'CVV matches',
        'N' => 'CVV does not match',
        'P' => 'CVV not processed',
        'S' => 'CVV should have been present',
        'U' => 'CVV request unable to be processed by issuer'
      }

      AVS_CODE_TRANSLATOR = {
        '0' =>  "Approved, Address verification was not requested.",
        'A' =>  "Approved, Address matches only.",
        'B' =>  "Address Match. Street Address math for international transaction Postal Code not verified because of incompatible formats (Acquirer sent both street address and Postal Code)",
        'C' =>  "Serv Unavailable. Street address and Postal Code not verified for international transaction because of incompatible formats (Acquirer sent both street and Postal Code).",
        'D' =>  "Exact Match, Street Address and Postal Code match for international transaction.",
        'F' =>  "Exact Match, Street Address and Postal Code match. Applies to UK only.",
        'G' =>  "Ver Unavailable, Non-U.S. Issuer does not participate.",
        'I' =>  "Ver Unavailable, Address information not verified for international transaction",
        'M' =>  "Exact Match, Street Address and Postal Code match for international transaction",
        'N' =>  "No - Address and ZIP Code does not match",
        'P' =>  "Zip Match, Postal Codes match for international transaction Street address not verified because of incompatible formats (Acquirer sent both street address and Postal Code).",
        'R' =>  "Retry - Issuer system unavailable",
        'S' =>  "Serv Unavailable, Service not supported",
        'U' =>  "Ver Unavailable, Address unavailable.",
        'W' =>  "ZIP match - Nine character numeric ZIP match only.",
        'X' =>  "Exact match, Address and nine-character ZIP match.",
        'Y' =>  "Exact Match, Address and five character ZIP match.",
        'Z' =>  "Zip Match, Five character numeric ZIP match only.",
        '1' =>  "Cardholder name and ZIP match AMEX only.",
        '2' =>  "Cardholder name, address, and ZIP match AMEX only.",
        '3' =>  "Cardholder name and address match AMEX only.",
        '4' =>  "Cardholder name match AMEX only.",
        '5' =>  "Cardholder name incorrect, ZIP match AMEX only.",
        '6' =>  "Cardholder name incorrect, address and ZIP match AMEX only.",
        '7' =>  "Cardholder name incorrect, address match AMEX only.",
        '8' =>  "Cardholder, all do not match AMEX only."
      }

      STANDARD_ERROR_CODE_MAPPING = {
        '14' => STANDARD_ERROR_CODE[:invalid_number],
        '80' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '82' => STANDARD_ERROR_CODE[:invalid_cvc],
        '54' => STANDARD_ERROR_CODE[:expired_card],
        '51' => STANDARD_ERROR_CODE[:card_declined],
        '05' => STANDARD_ERROR_CODE[:card_declined],
        '61' => STANDARD_ERROR_CODE[:card_declined],
        '62' => STANDARD_ERROR_CODE[:card_declined],
        '65' => STANDARD_ERROR_CODE[:card_declined],
        '93' => STANDARD_ERROR_CODE[:card_declined],
        '01' => STANDARD_ERROR_CODE[:call_issuer],
        '02' => STANDARD_ERROR_CODE[:call_issuer],
        '04' => STANDARD_ERROR_CODE[:pickup_card],
        '07' => STANDARD_ERROR_CODE[:pickup_card],
        '41' => STANDARD_ERROR_CODE[:pickup_card],
        '43' => STANDARD_ERROR_CODE[:pickup_card]
      }

      def initialize(options={})
        requires!(options, :orgid, :username, :password, :tid)

        super
      end

      def authorize(amount, creditcard, options = {})
        post = setup_post('auth')
        add_creditcard(post, creditcard)
        add_amount(post, amount)
        add_address(post, (options[:address] || options[:billing_address]))
        add_customer_data(post, options)

        commit(post)
      end

      def purchase(amount, creditcard, options={})
        post = setup_post('sale')
        add_creditcard(post, creditcard)
        add_amount(post, amount)
        add_address(post, (options[:address] || options[:billing_address]))
        add_customer_data(post, options)

        commit(post)
      end

      def refund(amount, trans_id, options={})
        # Attempt a void in case the transaction is unsettled
        post = setup_post('void')
        add_reference(post, trans_id)
        response = commit(post)
        return response if response.success?

        post = setup_post('refund')
        add_reference(post, trans_id)
        commit(post)
      end

      def capture(amount, trans_id, options = {})
        post = setup_post('capture')

        add_reference(post, trans_id)
        add_amount(post, amount)

        commit(post)
      end

      # No void, as PayHub's void does not work on authorizations

      def verify(creditcard, options={})
        authorize(100, creditcard, options)
      end

      private

      def setup_post(action)
        post = {}
        post[:orgid] = @options[:orgid]
        post[:tid] = @options[:tid]
        post[:username] = @options[:username]
        post[:password] = @options[:password]
        post[:mode] = (test? ? 'demo' : 'live')
        post[:trans_type] = action
        post
      end

      def add_reference(post, trans_id)
        post[:trans_id] = trans_id
      end

      def add_customer_data(post, options = {})
        post[:first_name] = options[:first_name]
        post[:last_name] = options[:last_name]
        post[:phone] = options[:phone]
        post[:email] = options[:email]
      end

      def add_address(post, address)
        return unless address
        post[:address1] = address[:address1]
        post[:address2] = address[:address2]
        post[:zip] = address[:zip]
        post[:state] = address[:state]
        post[:city] = address[:city]
      end

      def add_amount(post, amount)
        post[:amount] =  amount(amount)
      end

      def add_creditcard(post, creditcard)
        post[:cc] = creditcard.number
        post[:month] = creditcard.month.to_s
        post[:year] = creditcard.year.to_s
        post[:cvv] = creditcard.verification_value
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(post)
        success = false

        begin
          raw_response = ssl_post(live_url, post.to_json, {'Content-Type' => 'application/json'} )
          response = parse(raw_response)
          success = (response['RESPONSE_CODE'] == "00")
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        Response.new(success,
          response_message(response),
          response,
          test: test?,
          avs_result: {code: response['AVS_RESULT_CODE']},
          cvv_result: response['VERIFICATION_RESULT_CODE'],
          error_code: (success ? nil : STANDARD_ERROR_CODE_MAPPING[response['RESPONSE_CODE']]),
          authorization: response['TRANSACTION_ID']
        )
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        {
          error_message: "Invalid response received from the Payhub API.  Please contact wecare@payhub.com if you continue to receive this message." +
            "  (The raw response returned by the API was #{raw_response.inspect})"
        }
      end

      def response_message(response)
        (response['RESPONSE_TEXT'] || response["RESPONSE_CODE"] || response[:error_message])
      end
    end
  end
end
