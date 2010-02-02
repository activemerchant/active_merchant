require File.dirname(__FILE__) + '/viaklix'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # = Elavon Virtual Merchant Gateway
    #
    # == Example use:
    #
    #   gateway = ActiveMerchant::Billing::ElavonGateway.new(
    #               :login     => "my_virtual_merchant_id",
    #               :password  => "my_virtual_merchant_pin",
    #               :user      => "my_virtual_merchant_user_id" # optional
    #            )
    #
    #   # set up credit card obj as in main ActiveMerchant example
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #     :type       => 'visa',
    #     :number     => '41111111111111111',
    #     :month      => 10,
    #     :year       => 2011,
    #     :first_name => 'Bob',
    #     :last_name  => 'Bobsen'
    #   )
    #
    #   # run request
    #   response = gateway.purchase(1000, creditcard) # authorize and capture 10 USD
    #
    #   puts response.success?      # Check whether the transaction was successful
    #   puts response.message       # Retrieve the message returned by Elavon
    #   puts response.authorization # Retrieve the unique transaction ID returned by Elavon
    #
    class ElavonGateway < ViaklixGateway
      self.test_url = self.live_url = 'https://www.myvirtualmerchant.com/VirtualMerchant/process.do'

      self.display_name = 'Elavon MyVirtualMerchant'
      self.supported_countries = ['US', 'CA']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.elavon.com/'

      self.delimiter = "\n"
      self.actions = {
        :purchase => 'CCSALE',
        :credit => 'CCCREDIT',
        :authorize => 'CCAUTHONLY',
        :capture => 'CCFORCE'
      }
      
      # Authorize a credit card for a given amount.
      # 
      # ==== Parameters
      # * <tt>money</tt> - The amount to be authorized as an Integer value in cents.
      # * <tt>credit_card</tt> - The CreditCard details for the transaction.
      # * <tt>options</tt>
      #   * <tt>:billing_address</tt> - The billing address for the cardholder.      
      def authorize(money, creditcard, options = {})
        form = {}
        add_invoice(form, options)
        add_creditcard(form, creditcard)        
        add_address(form, options)   
        add_customer_data(form, options)
        commit(:authorize, money, form)
      end
      
      # Capture authorized funds from a credit card.
      # 
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured as an Integer value in cents.
      # * <tt>authorization</tt> - The approval code returned from the initial authorization.
      # * <tt>options</tt>
      #   * <tt>:credit_card</tt> - The CreditCard details from the initial transaction (required).
      def capture(money, authorization, options = {})
        requires!(options, :credit_card)
        
        form = {}
        add_reference(form, authorization)
        add_invoice(form, options)
        add_creditcard(form, options[:credit_card])
        add_customer_data(form, options)
        commit(:capture, money, form)
      end
      
      private
      def add_reference(form, authorization)
        form[:approval_code] = authorization
      end
      
      def authorization_from(response)
        response['approval_code']
      end
      
      def add_verification_value(form, creditcard)
        form[:cvv2cvc2] = creditcard.verification_value 
        form[:cvv2cvc2_indicator] = '1'
      end

      def add_address(form,options)
        billing_address = options[:billing_address] || options[:address] 
        
        if billing_address
          form[:avs_address]    = billing_address[:address1].to_s.slice(0, 30)
          form[:address2]       = billing_address[:address2].to_s.slice(0, 30)
          form[:avs_zip]        = billing_address[:zip].to_s.slice(0, 10)
          form[:city]           = billing_address[:city].to_s.slice(0, 30)
          form[:state]          = billing_address[:state].to_s.slice(0, 10)
          form[:company]        = billing_address[:company].to_s.slice(0, 50)
          form[:phone]          = billing_address[:phone].to_s.slice(0, 20)
          form[:country]        = billing_address[:country].to_s.slice(0, 50)
        end
                
        if shipping_address = options[:shipping_address]
          first_name, last_name = parse_first_and_last_name(shipping_address[:name])
          form[:ship_to_first_name]     = first_name.to_s.slice(0, 20)
          form[:ship_to_last_name]      = last_name.to_s.slice(0, 30)
          form[:ship_to_address1]       = shipping_address[:address1].to_s.slice(0, 30)
          form[:ship_to_address2]       = shipping_address[:address2].to_s.slice(0, 30)
          form[:ship_to_city]           = shipping_address[:city].to_s.slice(0, 30)
          form[:ship_to_state]          = shipping_address[:state].to_s.slice(0, 10)
          form[:ship_to_company]        = shipping_address[:company].to_s.slice(0, 50)
          form[:ship_to_country]        = shipping_address[:country].to_s.slice(0, 50)
          form[:ship_to_zip]            = shipping_address[:zip].to_s.slice(0, 10)
        end
      end
      
      def message_from(response)
        success?(response) ? response['result_message'] : response['errorMessage']
      end
      
      def success?(response)
        !response.has_key?('errorMessage')
      end
    end
  end
end

