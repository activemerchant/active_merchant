module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaystationGateway < Gateway

      self.live_url = self.test_url = "https://paystation.co.nz/direct/paystation.dll"

      # an "error code" of "0" means "No error - transaction successful"
      SUCCESSFUL_RESPONSE_CODE = '0'

      # an "error code" of "34" means "Future Payment Stored OK"
      SUCCESSFUL_FUTURE_PAYMENT = '34'

      # TODO: check this with paystation
      self.supported_countries = ['NZ']

      # TODO: check this with paystation (amex and diners need to be enabled)
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club ]

      self.homepage_url        = 'http://paystation.co.nz'
      self.display_name        = 'Paystation'

      self.default_currency    = 'NZD'
      self.money_format        = :cents

      def initialize(options = {})
        requires!(options, :paystation_id, :gateway_id)
		unless options.has_key?(:hmac_key)
			options[:hmac_key]= 0
		end 
        super
      end

      def authorize(money, credit_card, options = {})
        post = new_request

        add_invoice(post, options)
        add_amount(post, money, options)

        add_credit_card(post, credit_card)

        add_authorize_flag(post, options)

        commit(post)
      end

      def capture(money, authorization_token, options = {})
        post = new_request

        add_invoice(post, options)
        add_amount(post, money, options)

        add_authorization_token(post, authorization_token, options[:credit_card_verification])

        commit(post)
      end

      def purchase(money, payment_source, options = {})
        post = new_request

        add_invoice(post, options)
        add_amount(post, money, options)

        if payment_source.is_a?(String)
          add_token(post, payment_source)
        else
          add_credit_card(post, payment_source)
        end

        add_customer_data(post, options) if options.has_key?(:customer)

        commit(post)
      end

      def store(credit_card, options = {})
        post = new_request

        add_invoice(post, options)
        add_credit_card(post, credit_card)
        store_credit_card(post, options)

        commit(post)
      end

      private

        def new_request
          {
            :pi    => @options[:paystation_id], # paystation account id
            :gi    => @options[:gateway_id],    # paystation gateway id
            "2p"   => "t",                      # two-party transaction type
            :nr    => "t",                      # -- redirect??
            :df    => "yymm"                    # date format: optional sometimes, required others
          }
        end

        def add_customer_data(post, options)
          post[:mc] = options[:customer]
        end

        def add_invoice(post, options)
          requires!(options, :order_id)

          post[:ms] = options[:order_id] +"-"+ Time.now.to_f.to_s    # "Merchant Session", must be unique per request
          post[:mo] = options[:invoice]      # "Order Details", displayed in Paystation Admin
          post[:mr] = options[:description]  # "Merchant Reference Code", seen from Paystation Admin		
        end

        def add_credit_card(post, credit_card)

          post[:cn] = credit_card.number
          post[:ct] = credit_card.brand
          post[:ex] = format_date(credit_card.month, credit_card.year)
          post[:cc] = credit_card.verification_value if credit_card.verification_value?

        end

        # bill a token (stored via "store") rather than a Credit Card
        def add_token(post, token)
          post[:fp] = "t"    # turn on "future payments" - what paystation calls Token Billing
          post[:ft] = token
        end

        def store_credit_card(post, options)

          post[:fp] = "t"                                # turn on "future payments" - what paystation calls Token Billing
          post[:fs] = "t"                                # tells paystation to store right now, not bill
          post[:ft] = options[:token] if options[:token] # specify a token to use that, or let Paystation generate one

        end

        def add_authorize_flag(post, options)
          post[:pa] = "t" # tells Paystation that this is a pre-auth authorisation payment (account must be in pre-auth mode)
        end

        def add_authorization_token(post, auth_token, verification_value = nil)
          post[:cp] = "t" # Capture Payment flag – tells Paystation this transaction should be treated as a capture payment
          post[:cx] = auth_token
          post[:cc] = verification_value
        end

        def add_amount(post, money, options)

          post[:am] = amount(money)
          post[:cu] = options[:currency] || currency(money)

        end

        def parse(xml_response)
          response = {}

          xml = REXML::Document.new(xml_response)

          # for normal payments, the root node is <Response>
          # for "future payments", it's <PaystationFuturePaymentResponse>
          xml.elements.each("#{xml.root.name}/*") do |element|
            response[element.name.underscore.to_sym] = element.text
          end

          response
        end

        def commit(post)

          post[:tm] = "T" if test? # test mode
          post[:paystation]="_empty" # need include paystation param as "initiator flag for payment engine"
         
          temp_hash={}
          post.each do |key|
            temp_hash["pstn_"+key[0].to_s]=key[1]
          end
          post = temp_hash
          
          url = self.live_url+hmacGetParams(post)

          uri = URI.parse (url)
          https = Net::HTTP.new(uri.host, uri.port)
          https.use_ssl = true 
          https.verify_mode = OpenSSL::SSL::VERIFY_NONE
          request = Net::HTTP::Post.new(uri.request_uri)
          response = {}

          request.set_form_data(post)
          http_response = https.request(request)

          message  = message_from(response)
          response_text =http_response.body
          xml = REXML::Document.new(http_response.body)

          response = {}
          xml.elements.each("#{xml.root.name}/*") do |element|
            response[element.name.underscore.to_sym] = element.text
          end

          PaystationResponse.new(success?(response), message, response,
              :test          => (response[:tm] && response[:tm].downcase == "t"),
              :authorization => response[:paystation_transaction_id]
          )
        end

        def hmacGetParams(post)
          turi = URI.parse (self.live_url)
          thttps = Net::HTTP.new(turi.host, turi.port)
          thttps.use_ssl = true # if uri.scheme == 'https'
          thttps.verify_mode = OpenSSL::SSL::VERIFY_NONE
          trequest = Net::HTTP::Post.new(turi.request_uri)
          trequest.set_form_data(post)
          post_body = trequest.body

          
		  if @options[:hmac_key]!=0
			  hmac = makeHMAChash(post_body)

			  getParams ="?pstn_HMACTimestamp="+hmac[:pstn_HMACTimestamp]
			  getParams +="&pstn_HMAC="+hmac[:pstn_HMAC]
		  else 
			  getParams =""
		  end
			
        end

        def makeHMAChash (post_body)

          hmacTimestamp = Time.now.to_i.to_s
          hmacWebserviceName = "paystation"

          hmacBody= [hmacTimestamp].pack("a*")+[hmacWebserviceName].pack("a*")+[post_body].pack("a*")
          hmacHash= Digest::HMAC.hexdigest(hmacBody, @options[:hmac_key], Digest::SHA512)
          return {:pstn_HMACTimestamp=>hmacTimestamp, :pstn_HMAC => hmacHash}
        end

        def success?(response)
          (response[:ec] == SUCCESSFUL_RESPONSE_CODE) || (response[:ec] == SUCCESSFUL_FUTURE_PAYMENT)
        end

        def message_from(response)
          response[:em]
        end

        def format_date(month, year)
          "#{format(year, :two_digits)}#{format(month, :two_digits)}"
        end


    end

    class PaystationResponse < Response
      # add a method to response so we can easily get the token
      # for Validate transactions
      def token
        @params["future_payment_token"]
      end
    end
  end
end

