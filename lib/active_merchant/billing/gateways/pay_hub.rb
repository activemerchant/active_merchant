module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayHubGateway < Gateway
      self.live_url = 'https://checkout.payhub.com/transaction/api'
      self.test_url = 'https://checkout.payhub.com/transaction/api'
      
      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.payhub.com/'
      self.display_name = 'PayHub'

      RESPONSE_CODE_TRANSLATOR = {
        '00' => "Successful - Approved and completed",
        "01" => "Failed - Refer to issuer",
        "02" => "Failed - Refer to issuer-Special condition",
        "03" => "Failed - Invalid Merchant ID",
        "04" => "Failed - Pick up card (no fraud)",
        "05" => "Failed - Do not honor",
        "06" => "Failed - General error",
        "06*" => "Failed - Error response text from check service",
        "07" => "Failed - Pick up card, special condition (fraud account)",
        "08" => "Successful - Honor MasterCard with ID",
        "10" => "Failed - PayHub does not support partial approvals.",
        "11" => "Successful - VIP approval",
        "12" => "Failed - Invalid transaction",
        "13" => "Failed - Invalid amount",
        "14" => "Failed - Invalid card number",
        "15" =>   "Failed - No such issuer",
        "19" => "Failed - Re-enter transaction",
        "21" => "Failed - Unable to back out transaction",
        "28" => "Failed - File is temporarily unavailable",
        "34" => "Failed - MasterCard use only, Transaction Cancelled; Fraud Concern (Used in reversal requests only)",
        "39" => "Failed - No credit account",
        "41" => "Failed - Lost card, pick up (fraud account)",
        "43" => "Failed - Stolen card, pick up (fraud account)",
        "51" => "Failed - Insufficient funds",
        "52" => "Failed - No checking account",
        "53" => "Failed - No savings account",
        "54" => "Failed - Expired card",
        "55" => "Failed - Incorrect PIN",
        "57" => "Failed - Transaction not permitted-Card",
        "58" => "Failed - Transaction not permitted-Terminal",
        "59" => "Failed - Transaction not permitted-Merchant",
        "61" => "Failed - Exceeds withdrawal limit",
        "62" => "Failed - Invalid service code, restricted",
        "63" => "Failed - Security violation",
        "65" => "Failed - Activity limit exceeded",
        "75" => "Failed - PIN tried exceeded",
        "76" => "Failed - Unable to locate, no match",
        "77" => "Failed - Inconsistent data, reversed, or repeat",
        "78" => "Failed - No account",
        "79" => "Failed - Already reversed at switch",
        "80" => "Failed - Invalid date",
        "81" => "Failed - Cryptographic error",
        "82" => "Failed - CVV data is not correct",
        "83" => "Failed - Cannot verify PIN",
        "85" => "Successful - No reason to decline",
        "86" => "Failed - Cannot verify PIN",
        "91" => "Failed - Issuer or switch is unavailable",
        "92" => "Failed - Destination not found",
        "93" => "Failed - Violation, cannot complete",
        "94" => "Failed - Unable to locate, no match",
        "96" => "Failed - System malfunction"
      }
      
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

      def initialize(options={})
        requires!(options, :orgid, :username, :password, :tid)
        @orgid = options[:orgid]
        @username = options[:username]
        @password = options[:password]
        @tid = options[:tid]
        
        super
        
        options[:mode] = test? ? 'demo' : 'live'
      end

      def purchase(money, creditcard, options={})
        post = self.options
        add_creditcard(post, creditcard)
        add_amount(post, money, options)
        add_address(post, options.delete(:address))
        add_customer_data(post, options)

        post[:trans_type] = 'sale'

        commit(:post, post, options)
      end

      [:refund, :void].each do |action|
        define_method(action) do |options={}|
          requires!(options, :trans_id)
          post = self.options
          post[:trans_id] = options[:trans_id]
          post[:trans_type] = action.to_s

          commit(:post, post, options)
        end
      end

      private

      def add_customer_data(post, options)
        return unless options.kind_of?(Hash)
        post[:first_name] = options.delete(:first_name) if options[:first_name]
        post[:last_name] = options.delete(:last_name) if options[:last_name]
        post[:phone] = options.delete(:phone) if options[:phone]
        post[:email] = options.delete(:email) if options[:email]
      end

      def add_address(post, address)
        return unless card_exists?(post) && address.kind_of?(Hash)
        post[:address1] = address[:address1] if address[:address1]
        post[:address2] = address[:address2] if address[:address2]
        post[:zip] = address[:zip] if address[:zip]
        post[:state] = address[:state] if address[:state]
        post[:city] = address[:city] if address[:city]
      end

      def card_exists?(post)
        post[:cc] && post[:month] && post[:year] && post[:cvv]
      end

      def add_amount(post, money, options)
        post[:amount] =  amount(money)
      end

      def add_creditcard(post, creditcard)
        post[:cc] = creditcard.number
        post[:month] = creditcard.month.to_s
        post[:year] = creditcard.year.to_s
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, options={})
        parameters.merge!(options)
        # We really don't need. Just incase if payhub have different end points
        url = (test? ? test_url : live_url)

        raw_response = response = nil
        success = false
        begin
          raw_response = ssl_request(action, url, parameters.to_json, {'Content-Type' => 'application/json'} )
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
          :error_code => success ? nil : response['RESPONSE_CODE']
        )
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
        RESPONSE_CODE_TRANSLATOR[response['RESPONSE_CODE']] || response['RESPONSE_TEXT'] || response['error']['message']
      end
    end
  end
end
