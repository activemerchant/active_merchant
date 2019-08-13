module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RapidataGateway < Gateway
      # Rapidata is a UK based payment gateway that only supports
      # ACH/Direct debit and not creditcards.

      # the URLs are used in the authentication
      # ensure they don't have a trailing slash
      # :-( yeah, don't ask
      self.test_url = 'https://sandbox.rapidata.com'
      self.live_url = 'https://connect.rapidata.com'

      self.supported_countries = ['GB']
      self.default_currency = 'GBP'
      self.supported_cardtypes = []

      self.homepage_url = 'https://rapidataservices.com/'
      self.display_name = 'Rapidata'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :username, :password, :client_id)
        super
      end

      def create_direct_debit_plan(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        add_frequency(post, options)
        add_initial_date(post, options)
        add_metadata(post, options)

        commit('CreateDirectDebitInput', post, options)
      end

      alias_method :recurring_debit, :create_direct_debit_plan

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Bearer )([^\s])+/, '\1[FILTERED]').
          gsub(%r((&?username=)([^&]+))i, '\1[FILTERED]').
          gsub(%r((&?password=)([^&]+))i, '\1[FILTERED]').
          gsub(/("accountnumber\\?":\\?")(\d+)/i, '\1[FILTERED]').
          gsub(/("access_token\\?":\\?")([^\\?"]+)/i, '\1[FILTERED]')
      end

      private

      # Adds donor personal details
      #
      # === Options
      #
      # * <tt>title</tt>: the title of the donor
      # * <tt>first_name</tt>: first name of the donor
      # * <tt>last_name</tt>: last name of the donor
      # * <tt>email</tt>: the email of the donor
      #
      def add_customer_data(post, options)
        post['Title'] = options[:title] if options[:title]
        post['FirstName'] = options[:first_name]
        post['LastName'] = options[:last_name]
        post['Email'] = options[:email] if options[:email]
      end

      # Add metadata information
      #
      # === Options
      #
      # * <tt>database_id</tt>: an identifier supplied by Rapidata that identifies
      #   the database to which this record should be associated
      # * <tt>source</tt>: string, limited to 50 chars
      # * <tt>other1...other20</tt>: twenty optional parameters that can be set and sent
      #
      def add_metadata(post, options)
        post['DatabaseId'] = options[:database_id]
        post['Source'] = truncate(options[:source], 50)
        (1..20).each do |index|
          k = "other#{index}".to_sym
          post["Other#{index}"] = options[k] if options.key?(k)
        end
      end

      # Add address details
      #
      # === Options
      #
      # * <tt>address or billing_address</tt>: a Ruby array that contains an address
      # with :address(1|2|3), :city, :county and :postcode keys (all optional).
      #
      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        post['address1'] = truncate(address[:address1], 50) if address[:address1]
        post['address2'] = truncate(address[:address2], 50) if address[:address2]
        post['address3'] = truncate(address[:address3], 50) if address[:address3]
        post['town'] = truncate(address[:city], 50) if address[:city]
        post['county'] = truncate(address[:county], 50) if address[:county]
        post['postcode'] = truncate(address[:postcode], 50) if address[:postcode]
      end

      # Add frequency
      #
      # ==== Options
      #
      # * <tt>frequency_id</tt>: one of { 1: Monthly, 2: Quarterly,
      # 3: Half-yearly, 4: Yearly }
      #
      def add_frequency(post, options)
        post['FrequencyId'] = options[:frequency_id]
      end

      # Add first collection date
      #
      # ==== Options
      #
      # * <tt>first_collection_date</tt> -- Initial payment date
      #
      # Note: the first_collection_date needs to match what was configured
      #       in the client's database otherwise this will return an error
      #
      def add_initial_date(post, options)
        post['FirstCollectionDate'] = options[:first_collection_date].strftime("%Y-%m-%d")
      end

      # Add invoice details
      #
      # === Options
      #
      # * <tt>amount</tt>: The donation amount in decimal
      # * <tt>gift_aid</tt>: boolean to indicate if Gift Aid is included
      #                      https://www.gov.uk/donating-to-charity/gift-aid
      # * <tt>is_fulfilment</tt>: boolean to indicate if Rapidata is used to fulfil letters
      #
      def add_invoice(post, money, options)
        post['Amount'] = amount(money)
        post['GiftAid'] = options[:gift_aid] if options.key?(:gift_aid)
        post['IsFulfilment'] = options[:is_fulfilment] if options.key?(:is_fulfilment)
      end

      # Add payment details
      #
      # === Options
      #
      # * <tt>payment</tt>: the Payment object needs to be
      #   an instance of ActiveMerchant::Billing::Check
      #
      def add_payment(post, payment)
        post['AccountName'] = payment.name
        post['AccountNumber'] = payment.account_number
        post['SortCode'] = payment.routing_number
      end

      def parse(body)
        JSON.parse(body || "{}")
      end

      # Rapidata requires a token (usually with a TTL of 1h)
      # to query the API. Calling the /webapi/oauth/token endpoint
      # requires url-encoded parameters
      def authentication_data
        {
          grant_type: 'password',
          username: @options[:username],
          password: @options[:password],
          client_id: @options[:client_id],
          tenant: (test? ? test_url : live_url)
        }.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def headers(token)
        {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        }
      end

      # Build the URL with the path to the API endpoints
      def url(action)
        base = (test? ? test_url : live_url)
        path = (action == 'authenticate' ? '/webapi/oauth/token' : '/webapi/api/v1/customer/CreateDirectDebitPayer')

        "#{base}#{path}"
      end

      def commit(action, parameters, options)
        authentication_response = begin
          parse(ssl_post(url('authenticate'), authentication_data))
        rescue ResponseError => e
          return Response.new(
              false,
              parse(e.response.body || {}),
              parse(e.response.body || {}),
              error_code: e.response.code.to_s
            )
        end
        
        token = authentication_response['access_token']
        
        response = begin
          parse(ssl_post(url('sale'), post_data(action, parameters), headers(token)))
        rescue ResponseError => e
          raise unless(e.response.code.to_s =~ /4\d\d/)
          parse(e.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response.has_key?('ValidationResult') && 
          response['ValidationResult'].has_key?('errors') &&
          response['ValidationResult']['errors'].empty?
      end

      def message_from(response)
        # a successful message doesn't return a message
        # so we just do it for them
        if success_from(response)
          'OK'
        else
          response['Message']
        end
      end

      def authorization_from(response)
        response['URN'] if success_from(response)
      end

      def post_data(action, parameters = {})
        { action => parameters }.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
          response['ModelState']
        end
      end
    end
  end
end
