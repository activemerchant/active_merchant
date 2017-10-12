module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetbanxGateway < Gateway
      # Netbanx is the new REST based API for Optimal Payments / Paysafe
      self.test_url = 'https://api.test.netbanx.com/'
      self.live_url = 'https://api.netbanx.com/'

      self.supported_countries = %w(AF AX AL DZ AS AD AO AI AQ AG AR AM AW AU AT AZ BS BH BD BB BY BE BZ BJ BM BT BO BQ BA BW BV BR IO BN BG BF BI KH CM CA CV KY CF TD CL CN CX CC CO KM CG CD CK CR CI HR CU CW CY CZ DK DJ DM DO EC EG SV GQ ER EE ET FK FO FJ FI FR GF PF TF GA GM GE DE GH GI GR GL GD GP GU GT GG GN GW GY HT HM HN HK HU IS IN ID IR IQ IE IM IL IT JM JP JE JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT LU MO MK MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ MM NA NR NP NC NZ NI NE NG NU NF MP NO OM PK PW PS PA PG PY PE PH PN PL PT PR QA RE RO RU RW BL SH KN LC MF VC WS SM ST SA SN RS SC SL SG SX SK SI SB SO ZA GS SS ES LK PM SD SR SJ SZ SE CH SY TW TJ TZ TH NL TL TG TK TO TT TN TR TM TC TV UG UA AE GB US UM UY UZ VU VA VE VN VG VI WF EH YE ZM ZW)
      self.default_currency = 'CAD'
      self.supported_cardtypes = [
        :american_express,
        :diners_club,
        :discover,
        :jcb,
        :master,
        :maestro,
        :visa
      ]

      self.money_format = :cents

      self.homepage_url = 'https://processing.paysafe.com/'
      self.display_name = 'Netbanx by PaySafe'

      def initialize(options={})
        requires!(options, :account_number, :api_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_settle_with_auth(post)
        add_payment(post, payment)

        commit(:post, 'auths', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)

        commit(:post, 'auths', post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)

        commit(:post, "auths/#{authorization}/settlements", post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)

        commit(:post, "settlements/#{authorization}/refunds", post)
      end

      def void(authorization, options={})
        post = {}
        add_order_id(post, options)

        commit(:post, "auths/#{authorization}/voidauths", post)
      end

      def verify(credit_card, options={})
        post = {}
        add_payment(post, credit_card)
        add_order_id(post, options)

        commit(:post, 'verifications', post)
      end

      # note: when passing options[:customer] we only attempt to add the
      #       card to the profile_id passed as the options[:customer]
      def store(credit_card, options={})
        # locale can only be one of en_US, fr_CA, en_GB
        requires!(options, :locale)
        post = {}
        add_credit_card(post, credit_card, options)
        add_customer_data(post, options)

        commit(:post, 'customervault/v1/profiles', post)
      end

      def unstore(identification, options = {})
        customer_id, card_id = identification.split('|')

        if card_id.nil?
          # deleting the profile
          commit(:delete, "customervault/v1/profiles/#{CGI.escape(customer_id)}", nil)
        else
          # deleting the card from the profile
          commit(:delete, "customervault/v1/profiles/#{CGI.escape(customer_id)}/cards/#{CGI.escape(card_id)}", nil)
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("card\\?":{\\?"cardNum\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_settle_with_auth(post)
        post[:settleWithAuth] = true
      end

      def add_customer_data(post, options)
        post[:merchantCustomerId] = (options[:merchant_customer_id] || SecureRandom.uuid)
        post[:locale] = options[:locale]
      end

      def add_credit_card(post, credit_card, options = {})
        post[:card] ||= {}
        post[:card][:cardNum]    = credit_card.number
        post[:card][:holderName] = credit_card.name
        post[:card][:cvv]        = credit_card.verification_value
        post[:card][:cardExpiry] = expdate(credit_card)
        if options[:billing_address]
          post[:card][:billingAddress]  = map_address(options[:billing_address])
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currencyCode] = options[:currency] if options[:currency]
        add_order_id(post, options)

        if options[:billing_address]
          post[:billingDetails]  = map_address(options[:billing_address])
        end

      end

      def add_payment(post, credit_card_or_reference, options = {})
        post[:card] ||= {}
        if credit_card_or_reference.is_a?(String)
          post[:card][:paymentToken] = credit_card_or_reference
        else
          post[:card][:cardNum]    = credit_card_or_reference.number
          post[:card][:cvv]        = credit_card_or_reference.verification_value
          post[:card][:cardExpiry] = expdate(credit_card_or_reference)
        end
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :four_digits)
        month = format(credit_card.month, :two_digits)

        # returns a hash (necessary in the card JSON object)
        { :month => month, :year => year }
      end

      def add_order_id(post, options)
        post[:merchantRefNum] = (options[:order_id] || SecureRandom.uuid)
      end

      def map_address(address)
        return {} if address.nil?
        country = Country.find(address[:country]) if address[:country]
        mapped = {
          :street  => address[:address1],
          :city    => address[:city],
          :zip     => address[:zip],
        }
        mapped.merge!({:country => country.code(:alpha2).value}) unless country.blank?

        mapped
      end

      def parse(body)
        body.blank? ? {} : JSON.parse(body)
      end

      def commit(method, uri, parameters)
        params = parameters.to_json unless parameters.nil?
        response = begin
          parse(ssl_request(method, get_url(uri), params, headers))
        rescue ResponseError => e
          return Response.new(false, 'Invalid Login') if(e.response.code == '401')
          parse(e.response.body)
        end

        success = success_from(response)
        Response.new(
          success,
          message_from(success, response),
          response,
          :test => test?,
          :error_code => error_code_from(response),
          :authorization => authorization_from(success, get_url(uri), method, response)
        )
      end

      def get_url(uri)
        url = (test? ? test_url : live_url)
        if uri =~ /^customervault/
          "#{url}#{uri}"
        else
          "#{url}cardpayments/v1/accounts/#{@options[:account_number]}/#{uri}"
        end
      end

      def success_from(response)
        response.blank? || !response.key?('error')
      end

      def message_from(success, response)
        success ? 'OK' : (response['error']['message'] || "Unknown error - please contact Netbanx-Paysafe")
      end

      def authorization_from(success, url, method, response)
        if success && response.present? && url.match(/cardpayments\/v1\/accounts\/.*\//)
          response['id']
        elsif method == :post && url.match(/customervault\/.*\//)
          # auth for tokenised customer vault is returned as
          # customer_profile_id|card_id|payment_method_token
          #
          # customer_profile_id is the uuid that identifies the customer
          # card_id is the uuid that identifies the card
          # payment_method_token is the token that needs to be used when
          #                      calling purchase with a token
          #
          # both id's are used to unstore, the payment token is only used for
          # purchase transactions
          [response['id'], response['cards'].first['id'], response['cards'].first['paymentToken']].join("|")
        end
      end

      # Builds the auth and U-A headers for the request
      def headers
        {
          'Accept'        => 'application/json',
          'Content-type'  => 'application/json',
          'Authorization' => "Basic #{basic_auth}",
          'User-Agent'    => "Netbanx-Paysafe v1.0/ActiveMerchant #{ActiveMerchant::VERSION}"
        }
      end

      def basic_auth
        Base64.strict_encode64("#{@options[:account_number]}:#{@options[:api_key]}")
      end

      def error_code_from(response)
        unless success_from(response)
          case response['errorCode']
            when '3002' then STANDARD_ERROR_CODE[:invalid_number] # You submitted an invalid card number or brand or combination of card number and brand with your request.
            when '3004' then STANDARD_ERROR_CODE[:incorrect_zip] # The zip/postal code must be provided for an AVS check request.
            when '3005' then STANDARD_ERROR_CODE[:incorrect_cvc] # You submitted an incorrect CVC value with your request.
            when '3006' then STANDARD_ERROR_CODE[:expired_card] # You submitted an expired credit card number with your request.
            when '3009' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined by the issuing bank.
            when '3011' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined by the issuing bank because the card used is a restricted card. Contact the cardholder's credit card company for further investigation.
            when '3012' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined by the issuing bank because the credit card expiry date submitted is invalid.
            when '3013' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined by the issuing bank due to problems with the credit card account.
            when '3014' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined - the issuing bank has returned an unknown response. Contact the card holder's credit card company for further investigation.
            when '3015' then STANDARD_ERROR_CODE[:card_declined] # The bank has requested that you process the transaction manually by calling the cardholder's credit card company.
            when '3016' then STANDARD_ERROR_CODE[:card_declined] # The bank has requested that you retrieve the card from the cardholder – it may be a lost or stolen card.
            when '3017' then STANDARD_ERROR_CODE[:invalid_number] # You submitted an invalid credit card number with your request.
            when '3022' then STANDARD_ERROR_CODE[:card_declined] # The card has been declined due to insufficient funds.
            when '3023' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined by the issuing bank due to its proprietary card activity regulations.
            when '3024' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined because the issuing bank does not permit the transaction for this card.
            when '3032' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined by the issuing bank or external gateway because the card is probably in one of their negative databases.
            when '3035' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined due to exceeded PIN attempts.
            when '3036' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined due to an invalid issuer.
            when '3037' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined because it is invalid.
            when '3038' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined due to customer cancellation.
            when '3039' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined due to an invalid authentication value.
            when '3040' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined because the request type is not permitted on the card.
            when '3041' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined due to a timeout.
            when '3042' then STANDARD_ERROR_CODE[:card_declined] # Your request has been declined due to a cryptographic error.
            when '3045' then STANDARD_ERROR_CODE[:invalid_expiry_date] # You submitted an invalid date format for this request.
            when '3046' then STANDARD_ERROR_CODE[:card_declined] # The transaction was declined because the amount was set to zero.
            when '3047' then STANDARD_ERROR_CODE[:card_declined] # The transaction was declined because the amount exceeds the floor limit.
            when '3048' then STANDARD_ERROR_CODE[:card_declined] # The transaction was declined because the amount is less than the floor limit.
            when '3049' then STANDARD_ERROR_CODE[:card_declined] # The bank has requested that you retrieve the card from the cardholder – the credit card has expired.
            when '3050' then STANDARD_ERROR_CODE[:card_declined] # The bank has requested that you retrieve the card from the cardholder – fraudulent activity is suspected.
            when '3051' then STANDARD_ERROR_CODE[:card_declined] # The bank has requested that you retrieve the card from the cardholder – contact the acquirer for more information.
            when '3052' then STANDARD_ERROR_CODE[:card_declined] # The bank has requested that you retrieve the card from the cardholder – the credit card is restricted.
            when '3053' then STANDARD_ERROR_CODE[:card_declined] # The bank has requested that you retrieve the card from the cardholder – please call the acquirer.
            when '3054' then STANDARD_ERROR_CODE[:card_declined] # The transaction was declined due to suspected fraud.
            else STANDARD_ERROR_CODE[:processing_error]
          end
        end
      end
    end
  end
end
