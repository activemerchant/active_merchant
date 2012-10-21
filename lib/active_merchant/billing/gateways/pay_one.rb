module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayOneGateway < Gateway
      URL = 'https://api.pay1.de/post-gateway/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['DE']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      # The homepage URL of the gateway
      self.homepage_url = 'http://payone.de/'

      # The name of the gateway
      self.display_name = 'PayOne'

      self.money_format = :cents

      def initialize( options = {} )
        requires!(options, :mid, :portalid, :aid)
        @options = options
        super
      end

      def test?; @options[:test] || super; end

      def authorize( money, creditcard_or_userid, options = {} )
        post = {}
        add_reference(post, options)
        add_creditcard_or_userid(post, creditcard_or_userid, options)
        add_address(post, options)
        add_personal_data(post, options)
        add_invoice_details(post, options)

        commit('preauthorization', money, post)
      end

      def purchase( money, creditcard_or_userid, options = {} )
        post = {}
        add_creditcard_or_userid(post, creditcard_or_userid, options)
        add_address(post, options)
        add_personal_data(post, options)
        add_invoice_details(post, options)
        add_reference(post, options)

        commit('authorization', money, post)
      end

      def capture( money, authorization, options = {} )
        post = {}
        post[:id] = options[:id]
        post[:pr] = options[:pr]
        post[:no] = options[:no]
        post[:de] = options[:de]
        post[:txid] = authorization
        add_reference(post, options)
        commit('capture', money, post)
      end

      def create_access( offer_id, credit_card, options = {} )
        post = {}
        add_creditcard_or_userid(post, credit_card, options)
        commit('createaccess', nil, post)
      end

      private

      def add_invoice_details( post, options )
        if options[:invoice_details]
          post['id[1]'.to_sym] = options[:invoice_details][:id]
          post['pr[1]'.to_sym] = options[:invoice_details][:pr]
          post['no[1]'.to_sym] = options[:invoice_details][:no]
          post['de[1]'.to_sym] = options[:invoice_details][:de]
          post['va[1]'.to_sym] = options[:invoice_details][:va]
        end
      end

      def add_reference( post, options )
        post[:reference] = options[:reference]
      end

      def add_personal_data( post, options )
        %w(customerid salutation firstname lastname company email).each do |key|
          if options[key.to_sym] && !post[key.to_sym]
            post[key.to_sym] = options[key.to_sym]
          end
        end
      end

      def add_address( post, options )
        if options[:address]
          post[:street]   = options[:address][:street]
          post[:zip]      = options[:address][:zip]
          post[:city]     = options[:address][:city]
          post[:country]  = options[:address][:country]
        end
      end

      def add_invoice( post, options )
        post[:clearingtype] = 'rec'
        post[:vatid] = options[:vatid]
      end

      def add_creditcard_or_userid( post, creditcard_or_userid, options = {} )
        if creditcard_or_userid.instance_of?(CreditCard)
          add_creditcard(post, creditcard_or_userid)
        elsif creditcard_or_userid.instance_of?(Fixnum)
          add_userid(post, creditcard_or_userid)
        elsif creditcard_or_userid.instance_of?(String)
          add_invoice(post, options)
        end
      end

      def add_creditcard( post, creditcard )
        post[:cardpan] = creditcard.number
        post[:cardexpiredate] = expdate(creditcard)
        post[:cardcvc2] = creditcard.verification_value if creditcard.verification_value
        post[:clearingtype] = "cc"
        post[:firstname] = creditcard.first_name
        post[:lastname] = creditcard.last_name
        post[:cardtype] = case creditcard.brand
        when 'visa' then 'V'
        when 'master' then 'M'
        when 'diners_club' then 'D'
        when 'american_express' then 'A'
        when 'jcb' then 'J'
        when 'maestro' then 'O'
        end
      end

      def add_userid( post, userid )
        post[:userid] = userid
        post[:clearingtype] = "cc"
      end

      def parse( body )
        results = {}

        body.split(/\n/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end

        results
      end

      def commit( action, money, post )
        require 'digest/md5'

        post[:mid]        = @options[:mid]
        post[:portalid]   = @options[:portalid]
        post[:aid]        = @options[:aid]
        post[:mode]       = test? ? 'test' : 'live'
        post[:amount]     = money
        post[:request]    = action
        post[:currency]   = "EUR"
        post[:country]    = "DE"
        portal_key = ""
        post[:key]        = Digest::MD5.hexdigest(portal_key)

        clean_and_stringify_post(post)

        response = parse( ssl_post(URL, post_data(post)) )

        success = response["status"] == "APPROVED"

        #puts post_data(post) unless success

        message = message_from(response)

        Response.new(success, message, { :response => response, :userid => response["userid"] },
          { :test => test?, :authorization => response["txid"] }
        )
      end

      def message_from( response )
        status = case response["status"]
        when "ERROR"
          #puts response["errorcode"]
          #puts response["customermessage"]
          #puts response["errormessage"]
          response["errormessage"]
        else
          return "The transaction was successful"
        end
      end

      def post_data( post = {} )
        post.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end

      def clean_and_stringify_post( post )
        post.keys.reverse.each do |key|
          if post[key]
            post[key.to_s] = post[key]
          end
          post.delete(key)
        end
      end

      def expdate( creditcard )
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{year[-2..-1]}#{month}"
      end
    end
  end
end

