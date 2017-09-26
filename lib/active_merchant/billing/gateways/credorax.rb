module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CredoraxGateway < Gateway
      class_attribute :test_url, :live_na_url, :live_eu_url

      self.display_name = "Credorax Gateway"
      self.homepage_url = "https://www.credorax.com/"

      self.test_url = "https://intconsole.credorax.com/intenv/service/gateway"

      # The live URL is assigned on a per merchant basis once certification has passed
      # See the Credorax remote tests for the full certification test suite
      #
      # Once you have your assigned subdomain, you can override the live URL in your application via:
      # ActiveMerchant::Billing::CredoraxGateway.live_url = "https://assigned-subdomain.credorax.net/crax_gate/service/gateway"
      self.live_url = 'https://assigned-subdomain.credorax.net/crax_gate/service/gateway'

      self.supported_countries = %w(DE GB FR IT ES PL NL BE GR CZ PT SE HU RS AT CH BG DK FI SK NO IE HR BA AL LT MK SI LV EE ME LU MT IS AD MC LI SM)
      self.default_currency = "EUR"
      self.currencies_without_fractions = %w(CLP JPY KRW PYG VND)
      self.currencies_with_three_decimal_places = %w(BHD JOD KWD OMR RSD TND)

      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :maestro]

      RESPONSE_MESSAGES = {
        "00" => "Approved or completed successfully",
        "01" => "Refer to card issuer",
        "02" => "Refer to card issuer special condition",
        "03" => "Invalid merchant",
        "04" => "Pick up card",
        "05" => "Do not Honour",
        "06" => "Error",
        "07" => "Pick up card special condition",
        "08" => "Honour with identification",
        "09" => "Request in progress",
        "10" => "Approved for partial amount",
        "11" => "Approved (VIP)",
        "12" => "Invalid transaction",
        "13" => "Invalid amount",
        "14" => "Invalid card number",
        "15" => "No such issuer",
        "16" => "Approved, update track 3",
        "17" => "Customer cancellation",
        "18" => "Customer dispute",
        "19" => "Re-enter transaction",
        "20" => "Invalid response",
        "21" => "No action taken",
        "22" => "Suspected malfunction",
        "23" => "Unacceptable transaction fee",
        "24" => "File update not supported by receiver",
        "25" => "No such record",
        "26" => "Duplicate record update, old record replaced",
        "27" => "File update field edit error",
        "28" => "File locked out while update",
        "29" => "File update error, contact acquirer",
        "30" => "Format error",
        "31" => "Issuer signed-off",
        "32" => "Completed partially",
        "33" => "Pick-up, expired card",
        "34" => "Suspect Fraud",
        "35" => "Pick-up, card acceptor contact acquirer",
        "36" => "Pick up, card restricted",
        "37" => "Pick up, call acquirer security",
        "38" => "Pick up, Allowable PIN tries exceeded",
        "39" => "Transaction Not Allowed",
        "40" => "Requested function not supported",
        "41" => "Lost Card, Pickup",
        "42" => "No universal account",
        "43" => "Pick up, stolen card",
        "44" => "No investment account",
        "50" => "Do not renew",
        "51" => "Not sufficient funds",
        "52" => "No checking Account",
        "53" => "No savings account",
        "54" => "Expired card",
        "55" => "Pin incorrect",
        "56" => "No card record",
        "57" => "Transaction not allowed for cardholder",
        "58" => "Transaction not allowed for merchant",
        "59" => "Suspected Fraud",
        "60" => "Card acceptor contact acquirer",
        "61" => "Exceeds withdrawal amount limit",
        "62" => "Restricted card",
        "63" => "Security violation",
        "64" => "Wrong original amount",
        "65" => "Activity count limit exceeded",
        "66" => "Call acquirers security department",
        "67" => "Card to be picked up at ATM",
        "68" => "Response received too late.",
        "70" => "Invalid transaction; contact card issuer",
        "71" => "Decline PIN not changed",
        "75" => "Pin tries exceeded",
        "76" => "Wrong PIN, number of PIN tries exceeded",
        "77" => "Wrong Reference No.",
        "78" => "Record Not Found",
        "79" => "Already reversed",
        "80" => "Network error",
        "81" => "Foreign network error / PIN cryptographic error",
        "82" => "Time out at issuer system",
        "83" => "Transaction failed",
        "84" => "Pre-authorization timed out",
        "85" => "No reason to decline",
        "86" => "Cannot verify pin",
        "87" => "Purchase amount only, no cashback allowed",
        "88" => "MAC sync Error",
        "89" => "Authentication failure",
        "91" => "Issuer not available",
        "92" => "Unable to route at acquirer Module",
        "93" => "Cannot be completed, violation of law",
        "94" => "Duplicate Transmission",
        "95" => "Reconcile error / Auth Not found",
        "96" => "System malfunction",
        "R0" => "Stop Payment Order",
        "R1" => "Revocation of Authorisation Order",
        "R3" => "Revocation of all Authorisations Order"
      }

      def initialize(options={})
        requires!(options, :merchant_id, :cipher_key)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_email(post, options)
        add_3d_secure(post, options)
        add_echo(post, options)

        commit(:purchase, post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_email(post, options)
        add_3d_secure(post, options)
        add_echo(post, options)

        commit(:authorize, post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)
        add_echo(post, options)

        commit(:capture, post)
      end

      def void(authorization, options={})
        post = {}
        add_customer_data(post, options)
        reference_action = add_reference(post, authorization)
        add_echo(post, options)
        post[:a1] = generate_unique_id

        commit(:void, post, reference_action)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)
        add_echo(post, options)

        commit(:refund, post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)
        add_email(post, options)
        add_echo(post, options)

        commit(:credit, post)
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
          gsub(%r((b1=)\d+), '\1[FILTERED]').
          gsub(%r((b5=)\d+), '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        currency = options[:currency] || currency(money)

        post[:a4] = localized_amount(money, currency)
        post[:a1] = generate_unique_id
        post[:a5] = currency
        post[:h9] = options[:order_id]
      end

      CARD_TYPES = {
        "visa" => '1',
        "mastercard" => '2',
        "maestro" => '9'
      }

      def add_payment_method(post, payment_method)
        post[:c1] = payment_method.name
        post[:b2] = CARD_TYPES[payment_method.brand] || ''
        post[:b1] = payment_method.number
        post[:b5] = payment_method.verification_value
        post[:b4] = format(payment_method.year, :two_digits)
        post[:b3] = format(payment_method.month, :two_digits)
      end

      def add_customer_data(post, options)
        post[:d1] = options[:ip] || '127.0.0.1'
        if (billing_address = options[:billing_address])
          post[:c5] = billing_address[:address1]
          post[:c7] = billing_address[:city]
          post[:c10] = billing_address[:zip]
          post[:c8] = billing_address[:state]
          post[:c9] = billing_address[:country]
          post[:c2] = billing_address[:phone]
        end
      end

      def add_reference(post, authorization)
        response_id, authorization_code, request_id, action = authorization.split(";")
        post[:g2] = response_id
        post[:g3] = authorization_code
        post[:g4] = request_id
        action || :authorize
      end

      def add_email(post, options)
        post[:c3] = options[:email] || 'unspecified@example.com'
      end

      def add_3d_secure(post, options)
        return unless options[:eci] && options[:xid]
        post[:i8] = "#{options[:eci]}:#{(options[:cavv] || "none")}:#{options[:xid]}"
      end

      def add_echo(post, options)
        # The d2 parameter is used during the certification process
        # See remote tests for full certification test suite
        post[:d2] = options[:echo] unless options[:echo].blank?
      end

      ACTIONS = {
        purchase: '1',
        authorize: '2',
        capture: '3',
        authorize_void: '4',
        refund: '5',
        credit: '6',
        purchase_void: '7',
        refund_void: '8',
        capture_void: '9'
      }

      def commit(action, params, reference_action = nil)
        raw_response = ssl_post(url, post_data(action, params, reference_action))
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: "#{response["Z1"]};#{response["Z4"]};#{response["A1"]};#{action}",
          avs_result: AVSResult.new(code: response["Z9"]),
          cvv_result: CVVResult.new(response["Z14"]),
          test: test?
        )
      end

      def sign_request(params)
        params = params.sort
        params.each { |param| param[1].gsub!(/[<>()\\]/, ' ') }
        values = params.map { |param| param[1].strip }
        Digest::MD5.hexdigest(values.join + @options[:cipher_key])
      end

      def post_data(action, params, reference_action)
        params.keys.each { |key| params[key] = params[key].to_s}
        params[:M] = @options[:merchant_id]
        params[:O] = request_action(action, reference_action)
        params[:K] = sign_request(params)
        params.map {|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
      end

      def request_action(action, reference_action)
        if reference_action
          ACTIONS["#{reference_action}_#{action}".to_sym]
        else
          ACTIONS[action]
        end
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        Hash[CGI::parse(body).map{|k,v| [k.upcase,v.first]}]
      end

      def success_from(response)
        response["Z2"] == "0"
      end

      def message_from(response)
        if success_from(response)
          "Succeeded"
        else
          RESPONSE_MESSAGES[response["Z6"]] || response["Z3"] || "Unable to read error message"
        end
      end
    end
  end
end
