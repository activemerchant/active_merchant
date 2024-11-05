module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class PaywayDotComGateway < Gateway
      self.test_url = 'https://paywaywsdev.com/PaywayWS/Payment/CreditCard'
      self.live_url = 'https://paywayws.net/PaywayWS/Payment/CreditCard'

      self.supported_countries = %w[US CA]
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.money_format = :cents

      self.homepage_url = 'http://www.payway.com'
      self.display_name = 'Payway Gateway'

      STANDARD_ERROR_CODE_MAPPING = {
        '5012' => STANDARD_ERROR_CODE[:card_declined],
        '5035' => STANDARD_ERROR_CODE[:invalid_number],
        '5037' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '5045' => STANDARD_ERROR_CODE[:incorrect_zip]
      }

      # Payway to standard AVSResult codes.
      AVS_MAPPING = {
        'N1'  => 'I', #  No address given with order
        'N2'  => 'I', #  Bill-to address did not pass
        '““'  => 'R', #  AVS not performed (Blanks returned)
        'IU'  => 'G', #  AVS not performed by Issuer
        'ID'  => 'S', #  Issuer does not participate in AVS
        'IE'  => 'E', #  Edit Error - AVS data is invalid
        'IS'  => 'R', #  System unavailable or time-out
        'IB'  => 'B', #  Street address match. Postal code not verified due to incompatible formats (both were sent).
        'IC'  => 'C', #  Street address and postal code not verified due to incompatible format (both were sent).
        'IP'  => 'P', #  Postal code match. Street address not verified due to incompatible formats (both were sent).
        'A1'  => 'K', #  Accountholder name matches
        'A3'  => 'V', #  Accountholder name, billing address and postal code.
        'A4'  => 'L', #  Accountholder name and billing postal code match
        'A7'  => 'O', #  Accountholder name and billing address match
        'B3'  => 'H', #  Accountholder name incorrect, billing address and postal code match
        'B4'  => 'F', #  Accountholder name incorrect, billing postal code matches
        'B7'  => 'T', #  Accountholder name incorrect, billing address matches
        'B8'  => 'N', #  Accountholder name, billing address and postal code are all incorrect
        '??'  => 'R', #  A double question mark symbol indicates an unrecognized response from association
        'I1'  => 'X', #  Zip code +4 and Address Match
        'I2'  => 'W', #  Zip code +4 Match
        'I3'  => 'Y', #  Zip code and Address Match
        'I4'  => 'Z', #  Zip code Match
        'I5'  => 'M', #  +4 and Address Match
        'I6'  => 'W', #  +4 Match
        'I7'  => 'A', #  Address Match
        'I8'  => 'C' #  No Match
      }

      PAYWAY_WS_SUCCESS = '5000'

      SCRUB_PATTERNS = [
        %r(("password\\?":\\?")[^\\]+),
        %r(("fsv\\?":\\?")\d+),
        %r(("fsv\\?": \\?")\d+),
        %r(("accountNumber\\?":\\?")\d+),
        %r(("accountNumber\\?": \\?")[^\\]+),
        %r(("Invalid account number: )\d+)
      ].freeze

      SCRUB_REPLACEMENT = '\1[FILTERED]'

      def initialize(options = {})
        requires!(options, :login, :password, :company_id, :source_id)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_common(post, options)
        add_card_payment(post, payment, options)
        add_card_transaction_details(post, money, options)
        add_address(post, payment, options)

        commit('sale', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_common(post, options)
        add_card_payment(post, payment, options)
        add_card_transaction_details(post, money, options)
        add_address(post, payment, options)

        commit('authorize', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_common(post, options)
        add_card_transaction_name(post, authorization, options)

        commit('capture', post)
      end

      def credit(money, payment, options = {})
        post = {}
        add_common(post, options)
        add_card_payment(post, payment, options)
        add_card_transaction_details(post, money, options)
        add_address(post, payment, options)

        commit('credit', post)
      end

      def void(authorization, options = {})
        post = {}
        add_common(post, options)
        add_card_transaction_name(post, authorization, options)

        commit('void', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        SCRUB_PATTERNS.inject(transcript) do |text, pattern|
          text.gsub(pattern, SCRUB_REPLACEMENT)
        end
      end

      private

      def add_common(post, options)
        post[:userName] = @options[:login]
        post[:password] = @options[:password]
        post[:companyId] = @options[:company_id]
        post[:cardTransaction] = {}
        post[:cardTransaction][:sourceId] = @options[:source_id]
      end

      def add_address(post, payment, options)
        post[:cardAccount] ||= {}
        address = options[:billing_address] || options[:address] || {}
        first_name, last_name = split_names(address[:name])
        full_address = "#{address[:address1]} #{address[:address2]}".strip
        phone = address[:phone] || address[:phone_number]

        post[:cardAccount][:firstName] = first_name      if first_name
        post[:cardAccount][:lastName]  = last_name       if last_name
        post[:cardAccount][:address]   = full_address    if full_address
        post[:cardAccount][:city]      = address[:city]  if address[:city]
        post[:cardAccount][:state]     = address[:state] if address[:state]
        post[:cardAccount][:zip]       = address[:zip]   if address[:zip]
        post[:cardAccount][:phone]     = phone           if phone
      end

      def add_card_transaction_details(post, money, options)
        post[:cardTransaction][:amount] = amount(money)
        eci_type = options[:eci_type].nil? ? '1' : options[:eci_type]
        post[:cardTransaction][:eciType] = eci_type
        post[:cardTransaction][:processorSoftDescriptor] = options[:processor_soft_descriptor] if options[:processor_soft_descriptor]
        post[:cardTransaction][:tax] = options[:tax] if options[:tax]
      end

      def add_card_transaction_name(post, identifier, options)
        post[:cardTransaction][:name] = identifier
      end

      def add_card_payment(post, payment, options)
        # credit_card
        post[:accountInputMode] = 'primaryAccountNumber'

        post[:cardAccount] ||= {}
        post[:cardAccount][:accountNumber]  = payment.number
        post[:cardAccount][:fsv]            = payment.verification_value
        post[:cardAccount][:expirationDate] = expdate(payment)
        post[:cardAccount][:email]          = options[:email] if options[:email]
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :four_digits)
        month = format(credit_card.month, :two_digits)

        month + year
      end

      def parse(body)
        body.blank? ? {} : JSON.parse(body)
      end

      def commit(action, parameters)
        parameters[:request] = action

        url = (test? ? test_url : live_url)
        payload = parameters.to_json unless parameters.nil?

        response =
          begin
            parse(ssl_request(:post, url, payload, headers))
          rescue ResponseError => e
            return Response.new(false, 'Invalid Login') if e.response.code == '401'

            parse(e.response.body)
          end

        success = success_from(response)
        avs_result_code = response['cardTransaction'].nil? || response['cardTransaction']['addressVerificationResults'].nil? ? '' : response['cardTransaction']['addressVerificationResults']
        avs_result = AVSResult.new(code: AVS_MAPPING[avs_result_code])
        cvv_result = CVVResult.new(response['cardTransaction']['fraudSecurityResults']) if response['cardTransaction'] && response['cardTransaction']['fraudSecurityResults']

        Response.new(
          success,
          message_from(success, response),
          response,
          test: test?,
          error_code: error_code_from(response),
          authorization: authorization_from(response),
          avs_result:,
          cvv_result:
        )
      end

      def success_from(response)
        response['paywayCode'] == PAYWAY_WS_SUCCESS
      end

      def error_code_from(response)
        return '' if success_from(response)

        error = STANDARD_ERROR_CODE_MAPPING[response['paywayCode']].nil? ? STANDARD_ERROR_CODE[:processing_error] : STANDARD_ERROR_CODE_MAPPING[response['paywayCode']]
        return error
      end

      def message_from(success, response)
        return '' if response['paywayCode'].nil?

        return response['paywayCode'] + '-' + 'success' if success

        response['paywayCode']
      end

      def authorization_from(response)
        return '' if !success_from(response) || response['cardTransaction'].nil?

        response['cardTransaction']['name']
      end

      def headers
        {
          'Accept'        => 'application/json',
          'Content-type'  => 'application/json'
        }
      end
    end
  end
end
