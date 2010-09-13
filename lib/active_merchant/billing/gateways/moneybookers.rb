module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MoneybookersResponse
      def initialize response_body
        @response = response_body
      end

      def token
        return result = if(success?)
                          @response
                        else
                          nil
                        end
      end

      def success?
        @response =~ /^\w{32}$/
      end
    end

    class MoneybookersGateway < Gateway
      PAYMENT_URL = 'https://www.moneybookers.com/app/payment.pl'

      # Moneybookers API version
      # September 03, 2009
      API_VERSION = "6.8"

      class << self
        # TODO check additional supported countries
        # supported_countries = ['DE']
        # TODO check additional supported card types
        # supported_cardtypes = [:visa, :master, :american_express]
        homepage_url        = PAYMENT_URL
        test_redirect_url   = PAYMENT_URL
        money_format        = :cents # 100 is 1.00 Euro
        default_currency    = 'EUR'
        display_name        = 'Moneybookers Payment Gateway'
      end

      def initialize(options = {})
        requires!(options,
                  :pay_to_email,        # merchant email
                  :return_url,          # after client purchases
                  :cancel_url,          # after client cancels
                  :language,            # displayed mb page language
                  # notification from mb after successful payment
                  # may also be an email, but you may use
                  # :notify_email additionally for that
                  :notify_url,
                  # details show up in clients payments history
                  :detail1_description, # e.g. "Product ID:"
                  :detail1_text
                  )
        @options = options
        super
      end

      def setup_purchase(amount)
        data = post_data(amount,{:prepare_only => "1"})
        @response = MoneybookersResponse.new(ssl_post(PAYMENT_URL, data))
      end

      def checkout_url
        @response.success? && redirect_url || nil
      end

      private
      def redirect_url
        "#{PAYMENT_URL}?sid=#{@response.token}"
      end

      def currency
        @options[:currency] || "EUR"
      end

      def post_data(amount_in_cents, parameters = {})
        post = {}
        # mandatory fields
        post[:pay_to_email]        = @options[:pay_to_email]
        post[:return_url]          = @options[:return_url]
        post[:return_url_text]     = @options[:return_url_text]
        post[:cancel_url]          = @options[:cancel_url]
        post[:detail1_description] = @options[:detail1_description]
        post[:detail1_text]        = @options[:detail1_text]
        post[:amount]              = amount(amount_in_cents)
        post[:language]            = @options[:language]
        post[:status_url]          = @options[:notify_url] || @options[:status_url]
        post[:status_url2]         = @options[:notify_email] || @options[:status_url2]
        post[:currency]            = currency

        # billing_address
        if @options[:billing_address]
          post[:pay_from_email]        = @options[:email]
          post[:title]                 = @options[:billing_address][:title]
          post[:firstname]             = @options[:billing_address][:firstname]
          post[:lastname]              = @options[:billing_address][:lastname]
          post[:date_of_birth]         = @options[:billing_address][:date_of_birth]
          post[:address]               = @options[:billing_address][:address]
          post[:address2]              = @options[:billing_address][:address2]
          post[:phone_number]          = @options[:billing_address][:phone_number]
          post[:postal_code]           = @options[:billing_address][:postal_code]
          post[:city]                  = @options[:billing_address][:city]
          post[:state]                 = @options[:billing_address][:state]
          post[:country]               = @options[:billing_address][:country]
        end

        # Merchant may specify a detailed calculation for the total
        # amount payable. Please note that moneybookers does not check
        # the validity of these data - they are only displayed in the
        # details section of Step 2 of the payment process.
        [:amount2_description,  # e.g. "Product Price:"
         :amount2,              # e.g. "29.90"
         :amount3_description,  # e.g. "Handling Fees:"
         :amount3,              # e.g. "3.10"
         :amount4_description,  # e.g. "VAT (20%):"
         :amount4,              # e.g. "6.60"

         # customer
         :dynamic_descriptor,   # merchant name
         :confirmation_note,    # thank you note
         :merchant_fields,      # fields which will be sent back to you

         # product details (up to 5 fields)
         # Merchant may show up to 5 details about the product or
         # transfer in the 'Payment Details' section of Step 2 of the
         # process. The detail1_descritpion is shown on the left side.
         :detail2_description,
         :detail2_text,
         :detail3_description,
         :detail3_text,
         :detail4_description,
         :detail4_text,
         :detail5_description,
         :detail5_text,

         # recurring billing
         :rec_period,
         :rec_grace_period,
         :rec_cycle,
         :ondemand_max_currency
        ].each do |f|
          post[f] = @options[f] if @options[f]
        end

        request = post.merge(parameters).collect do |key, value|
          "#{key}=#{CGI.escape(value.to_s)}"
        end.join("&")

        request
      end
    end
  end
end

