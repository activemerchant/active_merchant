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
        post = add_credential_cc_and_customer_data(amount, creditcard, options)
        post[:trans_type] = 'auth'

        commit(:post, post, options)
      end

      def purchase(amount, creditcard, options={})
        post = add_credential_cc_and_customer_data(amount, creditcard, options)
        post[:trans_type] = 'sale'

        commit(:post, post, options)
      end

      # Since Payhub does not support partial refund,
      # method signature shouldn't include amount parameter
      def refund(trans_id, options={})
        post = add_credentials_for('refund', trans_id)

        commit(:post, post, options)
      end

      def void(trans_id, options={})
        post = add_credentials_for('void', trans_id)

        commit(:post, post, options)
      end

      def capture(amount, trans_id, options = {})
        post = add_credentials_for('capture', trans_id)
        add_amount(post, amount)

        commit(:post, post, options)
      end

      private

      def add_credential_cc_and_customer_data(amount, creditcard, options = {})
        post = {}
        add_credentials(post)
        add_creditcard(post, creditcard)
        add_amount(post, amount)
        add_address(post, options.delete(:address))
        add_customer_data(post, options)
        post
      end

      def add_credentials(post)
        post[:orgid] = @options[:orgid]
        post[:tid] = @options[:tid]
        post[:username] = @options[:username]
        post[:password] = @options[:password]
      end

      def add_credentials_for(action, trans_id)
        post = {}
        add_credentials(post)
        post[:trans_id] = trans_id
        post[:trans_type] = action
        post
      end

      def add_customer_data(post, options = {})
        post[:first_name] = options.delete(:first_name)
        post[:last_name] = options.delete(:last_name)
        post[:phone] = options.delete(:phone)
        post[:email] = options.delete(:email)
      end

      def add_address(post, address = {})
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

      def commit(action, post, options={})
        add_mode(post)
        post.merge!(options)
        raw_response = response = nil
        success = false

        begin
          raw_response = ssl_request(action, live_url, post.to_json, {'Content-Type' => 'application/json'} )
          response = parse(raw_response)
          success = response['RESPONSE_CODE'] == "00"
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        Response.new(success,
          response_message(response),
          response,
          :test => test?,
          :avs_result => { :code => response['AVS_RESULT_CODE'] },
          :cvv_result => response['VERIFICATION_RESULT_CODE'],
          :error_code => success ? nil : STANDARD_ERROR_CODE_MAPPING[response['RESPONSE_CODE']],
          :authorization => response['TRANSACTION_ID']
        )
      end

      def add_mode(post)
        post[:mode] = test? ? 'demo' : 'live'
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Payhub API.  Please contact wecare@payhub.com if you continue to receive this message.'
        msg.concat '  (The raw response returned by the API was #{raw_response.inspect})'
        {
          'error' => {
            'message' => msg
          }
        }
      end

      def response_message(response)
        response['RESPONSE_TEXT'] || response["RESPONSE_CODE"] || response['error']['message']
      end
    end
  end
end
