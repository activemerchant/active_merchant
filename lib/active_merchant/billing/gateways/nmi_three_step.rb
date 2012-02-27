module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NmiThreeStepGateway < Gateway
      LIVE_URL = 'https://secure.nmi.com/api/v2/three-step'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://nmi.com/'
      
      # The name of the gateway
      self.display_name = 'NMI Three Step Redirect'
      
      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end
      
      def setup_purchase(money, options = {})
        requires!(options, :return_url)
        commit build_setup_request(money, options)
      end

      # A helper to get the 2nd step form URL from the 1st step response
      def form_url_for(response)
        response.params["form_url"]
      end

      # Now that the Payment Gateway has collected the sensitive customer data, you 
      # must submit another behind-the-scenes direct POST to complete the trasanction 
      # using the token-id
      def purchase(token)
        commit build_sale_request(token)
      end
    
      private
      
      def build_response(r)
        success = r["result"] == "1"
        message = r["result_text"]
        options = {
          :authorization => r["transaction_id"],
          :fraud_review => false,
          :avs_result => {code: r["avs_result"]},
          :cvv_result => r["cvv_result"]
        }
        Response.new(success, message, r, options)
      end

      def commit(request_body)
        data = ssl_post(LIVE_URL, request_body, {"content-type" => "text/xml"})
        hash = Hash.from_xml(data)["response"]
        build_response(hash)
      end

      def build_setup_request(money, options)
        builder = Builder::XmlMarkup.new
        builder.instruct!
        builder.tag!( "sale") do |sale|
          sale.tag!("api-key", @options[:login])
          sale.tag!("redirect-url", options[:return_url])
          sale.tag!("amount", amount(money))
          sale.tag!("ip-address", options[:ip]) if options[:ip]
          sale.tag!("order-description", options[:description]) if options[:description]
          sale.tag!("customer-id", options[:customer]) if options[:customer]
          sale.tag!("merchant-receipt-email", options[:merchant_email]) if options[:merchant_email]
          sale.tag!("customer-receipt", true)
          sale.tag!("merchant-defined-field-1", options[:custom_1]) if options[:custom_1]
          sale.tag!("merchant-defined-field-2", options[:custom_2]) if options[:custom_2]
          sale.tag!("tax-amount", amount(options[:tax])) if options[:tax]
          sale.tag!("shipping-amount", amount(options[:shipping])) if options[:shipping]
        end
      end

      def build_sale_request(token)
        builder = Builder::XmlMarkup.new
        builder.instruct!
        builder.tag! "complete-action" do |c|
          c.tag! "api-key", @options[:login]
          c.tag! "token-id", token
        end
      end
     
    end # NmiThreeStepGateway
  end # Billing
end # ActiveMerchant

