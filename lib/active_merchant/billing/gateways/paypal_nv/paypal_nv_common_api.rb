require 'cgi'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This module is included in both PaypalGateway and PaypalExpressGateway
    module PaypalNvCommonAPI
      def self.included(base)
        base.default_currency = 'USD'
        base.cattr_accessor :pem_file
        base.cattr_accessor :signature
      end

      API_VERSION = '50.0000'

      URLS = {
        :test => { :certificate => 'https://api.sandbox.paypal.com/nvp/',
                   :signature   => 'https://api-3t.sandbox.paypal.com/nvp/' },
        :live => { :certificate => 'https://api.paypal.com/nvp/',
                   :signature   => 'https://api-3t.paypal.com/nvp/' }
      }

      AUSTRALIAN_STATES = {
        'ACT' => 'Australian Capital Territory',
        'NSW' => 'New South Wales',
        'NT'  => 'Northern Territory',
        'QLD' => 'Queensland',
        'SA'  => 'South Australia',
        'TAS' => 'Tasmania',
        'VIC' => 'Victoria',
        'WA'  => 'Western Australia'
      }

      SUCCESS_CODES = [ 'Success', 'SuccessWithWarning' ]

      # The gateway must be configured with either your PayPal PEM file
      # or your PayPal API Signature.  Only one is required.
      #
      # <tt>:pem</tt>         The text of your PayPal PEM file. Note
      #                       this is not the path to file, but its
      #                       contents. If you are only using one PEM
      #                       file on your site you can declare it
      #                       globally and then you won't need to
      #                       include this option
      #
      # <tt>:signature</tt>   The text of your PayPal signature.
      #                       If you are only using one API Signature
      #                       on your site you can declare it
      #                       globally and then you won't need to
      #                       include this option

      def initialize(options = {})
        requires!(options, :login, :password)

        @options = {
          :pem => pem_file,
          :signature => signature
        }.update(options)

        if @options[:pem].blank? && @options[:signature].blank?
          raise ArgumentError, "An API Certificate or API Signature is required to make requests to PayPal"
        end

        super
      end

      def test?
        @options[:test] || super
      end

      def reauthorize(money, authorization, options = {})
        commit 'DoReauthorization', build_reauthorize_request(money, authorization, options)
      end

      def capture(money, authorization, options = {})
        commit 'DoCapture', build_capture_request(money, authorization, options)
      end

      # Transfer money to one or more recipients.
      #
      #   gateway.transfer 1000, 'bob@example.com',
      #     :subject => "The money I owe you", :note => "Sorry it's so late"
      #
      #   gateway.transfer [1000, 'fred@example.com'],
      #     [2450, 'wilma@example.com', :note => 'You will receive another payment on 3/24'],
      #     [2000, 'barney@example.com'],
      #     :subject => "Your Earnings", :note => "Thanks for your business."
      #
      def transfer(*args)
        commit 'MassPay', build_mass_pay_request(*args)
      end

      def void(authorization, options = {})
        commit 'DoVoid', build_void_request(authorization, options)
      end

      def credit(money, identification, options = {})
        commit 'RefundTransaction', build_credit_request(money, identification, options)
      end

      private
      def build_reauthorize_request(money, authorization, options)
        post = {}
        add_pair(post, :authorizationid, authorization)
        add_amount(post, money, options)
        post
      end

      # - Softdescriptor - max len 22
      def build_capture_request(money, authorization, options)
        post = {}
        add_pair(post, :authorizationid, authorization)
        add_amount(post, money, options)
        add_pair(post, :completetype, (options[:complete] || "Complete"))
        add_pair(post, :note, options[:description]) if options[:description]
        add_pair(post, :softdescriptor, options[:soft_descriptor]) if options[:soft_descriptor]
        post
      end


      def build_credit_request(money, identification, options)
        post = {}
        add_pair(post, :transactionid, identification)
        add_pair(post, :refundtype, options[:refund_type] || "Partial")
        add_pair(post, :note, options[:description]) if options[:description]
        add_amount(post,  money, options)
        post
      end

      def build_void_request(authorization, options)
        post = {}
        add_pair(post, :authorizationid, authorization)
        add_pair(post, :note, options[:description]) if options[:description]
        post
      end

      # TODO: make transfer check for recipient or unique recipiend id
      # They are not supposed to be mixed
      def build_mass_pay_request(*args)
        post = {}
        default_options = args.last.is_a?(Hash) ? args.pop : {}
        recipients = args.first.is_a?(Array) ? args : [args]
        
        if recipients.size > 250
          raise ArgumentError, "PayPal only supports transferring money to 250 recipients at a time"
        end
        
        add_pair(post, :currencycode, default_options[:currency])
        add_pair(post, :emailsubject, default_options[:subject]) if default_options[:subject]
        
        recipients.each_with_index do |(money, recipient, options), index|
          options ||= default_options
          add_trans_item(post, index, :amt, amount(money))
          add_trans_item(post, index, :email, recipient)
          add_trans_item(post, index, :note, options[:note]) if options[:note]
          add_trans_item(post, index, :uniqueid, options[:unique_id]) if options[:unique_id]
        end
        post
      end

      def add_trans_item(post, id, label, value)
        add_pair(post, "l_#{label}#{id}", value)
      end

      def parse(data)
        fields = {}
        for line in data.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key.underscore.to_sym] = CGI.unescape(value)
        end
        fields
      end

      def post_data(action, post)
        post[:method]     = action
        post[:user]       = @options[:login]
        post[:pwd]        = @options[:password]
        post[:signature]  = @options[:signature] unless @options[:signature].blank?
        post[:subject]    = @options[:subject] unless @options[:subject].blank?
        post[:version]    = API_VERSION

        post.collect {|k,v| "#{k.to_s.upcase}=#{CGI.escape(v.to_s)}" }.join("&")
      end

      def add_email(post, options)
        add_pair(post, :email, options[:email]) if options[:email]
      end

      def endpoint_url
        URLS[test? ? :test : :live][@options[:signature].blank? ? :certificate : :signature]
      end

      def commit(action, post)
        response = parse(ssl_post(endpoint_url, post_data(action, post)))

        build_response(successful?(response), message_from(response), response,
           :test => test?,
           :authorization => authorization_from(response),
           :avs_result => { :code => response[:avscode] },
           :cvv_result => response[:cvv2_match]
        )
      end

      def authorization_from(response)
        response[:transactionid] || response[:authorizationid] # latter one is from reauthorization
      end

      def successful?(response)
        SUCCESS_CODES.include?(response[:ack])
      end

      def message_from(response)
        if successful?(response)
          response[:message]
        else 
          response[:l_longmessage0] || response[:ack]
        end
      end

      private
      def add_pair(post, key, value, options = {})
        post[key] = value if not value.blank? || options[:allow_blank]
      end

      def add_addresses(post, options)
        billing_address = options[:billing_address] || options[:address]
        unless options[:no_shipping]
          shipping_address = options[:shipping_address] || billing_address
        end

        add_billing_address(post, billing_address)
        add_shipping_address(post, shipping_address)
      end

      def format_date(month, year)
        month = format(month, :two_digits)
        year  = format(year, :four_digits)

        "#{month}#{year}"
      end

      def add_credit_card(post, credit_card)
        post[:creditcardtype] = credit_card_type(card_brand(credit_card))
        post[:firstname]      = credit_card.first_name
        post[:lastname]       = credit_card.last_name
        post[:acct]           = credit_card.number
        post[:expdate]        = format_date(credit_card.month, credit_card.year)
        post[:cvv2] = credit_card.verification_value if credit_card.verification_value?
        if requires_start_date_or_issue_number?(credit_card)
          post[:cardstart] = format_date(credit_card.start_month, credit_card.start_year) unless credit_card.start_month.blank? || credit_card.start_year.blank?
          post[:cardissue] = credit_card.issue_number unless credit_card.issue_number.blank?
        end
      end

      def add_customer_data(post, options)
        add_pair(post, :ipaddress, options[:ip])
        add_pair(post, :email, options[:email])
      end

      def add_billing_address(post, address)
        return if address.nil?
        add_pair(post, :companyname, address[:company])
        add_pair(post, :street, address[:address1])
        add_pair(post, :street2, address[:address2])
        add_pair(post, :city, address[:city])
        add_pair(post, :state, address[:state])
        add_pair(post, :zip, address[:zip])
        add_pair(post, :countrycode, address[:country])
        add_pair(post, :phonenum, address[:phone])
      end

      def add_shipping_address(post, address)
        return if address.nil?
        add_pair(post, :shiptoname, address[:name])
        add_pair(post, :shiptostreet, address[:address1])
        add_pair(post, :shiptostreet2, address[:address2]) if address[:address2]
        add_pair(post, :shiptocity, address[:city])
        add_pair(post, :shiptostate, address[:state])
        add_pair(post, :shiptozip, address[:zip])
        add_pair(post, :shiptocountrycode, address[:country])
        add_pair(post, :shiptophonenum, address[:phone])
      end

      def add_invoice(post, options)
        add_pair(post, :invnum, options[:order_id]) if options[:order_id]
        add_pair(post, :desc, options[:description]) if options[:description]
        add_pair(post, :custom, options[:custom_code]) if options[:custom_code]
        add_line_items(post, options[:line_items]) if options[:line_items]
      end

      def add_line_items(post, line_items)
        line_items.each_with_index do |line_item, index|
          add_line_item(post, line_item, index)
        end
      end

      def add_line_item(post, line_item, index)
        add_line_item_pair(post, :name, line_item[:description], index)
        add_line_item_pair(post, :number, line_item[:sku], index)
        add_line_item_pair(post, :qty, line_item[:quantity], index)
        add_line_item_pair(post, :taxamt, amount(line_item[:tax]), index) if line_item[:tax]
        add_line_item_pair(post, :amt, amount(line_item[:amount]), index) if line_item[:amount]
      end
      
      def add_line_item_pair(post, name, value, index)
        add_pair(post, "l_#{name}#{index}", value)
      end

      def add_amount(post, money, options)
        add_pair(post, :currencycode, options[:currency] || currency(money))
        add_pair(post, :amt, amount(money), :allow_blank => false)
      end

      def add_subtotals(post, options)
        # All of the values must be included together and add up to the order total
        if options[:subtotal]
          add_pair(post, :itemamt, amount(options[:subtotal]))
          add_pair(post, :shippingamt, amount(options[:shipping] || 0))
          add_pair(post, :handlingamt, amount(options[:handling] || 0))
          add_pair(post, :taxamt, amount(options[:tax] || 0))
        end
      end
    end
  end
end
