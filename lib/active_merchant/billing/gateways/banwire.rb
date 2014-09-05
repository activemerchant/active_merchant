module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BanwireGateway < Gateway
      self.test_url = 'https://test.banwire.com/sw/?action=active_merchant&sandbox=qa'
      self.live_url = 'https://test.banwire.com/sw/?action=active_merchant'

      self.supported_countries = ['MX']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.banwire.com/'
      self.display_name = 'Banwire'
	  self.money_format = :dollars
      self.default_currency = 'MXN'

      def initialize(options={})
        requires!(options, :login)
        super
      end

      def purchase(money, payment, options={})
        post = {}
		add_response_type(post)
		add_order_data(post, money, options)
		add_special_data(post,options)
		add_customer_data(post, options)
		add_shipment_address(post, options)
		add_payment(post, payment, options)

        commit('&payment=direct', post)
      end
	  
      def authorize(money, payment, options={})
        post = {}
        add_response_type(post)
		add_order_data(post, money, options)
		add_special_data(post,options)
		add_customer_data(post, options)
		add_shipment_address(post, options)
		add_payment(post, payment, options)

        commit('&payment=direct', post)
      end

      def refund(money, identifier, options={})
		post = {}
		
		post[:id] = identifier
		add_auth_data(post, options)
	  
        commit('&payment=transaction_back', post)
      end

      private
	
	  def add_response_type(post)
		post[:response_format] = "JSON"
	  end
	  
	  def add_auth_data(post, options)
		post[:user] = @options[:login] if @options[:login]
	  end
	  
	  def add_order_data(post, money, options)
		post[:ORD_CURR_CD] = (options[:currency] || currency(money)).upcase
		post[:ORD_ID] = options[:order_id]
		post[:ORD_AMT] = amount(money)
		post[:ORD_CONCEPT] = options[:description]
	  end
	  
	  def add_special_data(post, options)
		post[:EBT_PREVCUST] = "N"
		post[:EBT_DEVICEPRINT] = options[:device_print] if options[:device_print]
		post[:CUST_IP] = options[:ip] if options[:ip]
		post[:ebWEBSITE] = options[:web_site] if options[:web_site]
		post[:PROD_DEL_CD] = options[:web_site] || "CNC"
		post[:NOTIFY_URL] = options[:notify_url] if options[:notify_url]
		
		add_auth_data(post, options)
	  end
	  
      def add_customer_data(post, options)
	    address = (options[:address] || options[:billing_address])

		post[:CUST_USER_ID] = options[:cust_id] if options[:cust_id]
        post[:CUST_PHONE] = options[:phone]
        post[:CUST_EMAIL] = options[:email]
		post[:CUST_FNAME] = options[:name] if options[:name]
		post[:CUST_MNAME] = options[:middle_name] if options[:middle_name]
		post[:CUST_LNAME] = options[:last_name] if options[:last_name]
		
		post[:CUST_HOME_PHONE] = options[:home_phone] if options[:home_phone]
		post[:CUST_WORK_PHONE] = options[:work_phone] if options[:work_phone]
		
		post[:CUST_ADDR1] = address[:address] if address[:address]
		post[:CUST_CITY] = address[:city] if address[:city]
		post[:CUST_STPR_CD] = address[:state] if address[:state]
		post[:CUST_POSTAL_CD] = address[:zip] if address[:zip]
		post[:CUST_CNTRY_CD] = address[:contry] if address[:contry]
      end
	  
	  def add_shipment_address(post, options)
		address = (options[:shipping_address] || {})
		
		post[:SHIP_ID] = address[:id] if address[:id]
		post[:SHIP_HOME_PHONE] = address[:phone] if address[:phone]
		post[:SHIP_EMAIL] = address[:email] if address[:email]
		post[:SHIP_FNAME] = address[:name] if address[:name]
		post[:SHIP_LNAME] = address[:last_name] if address[:last_name]
		post[:SHIP_MNAME] = address[:middle_name] if address[:middle_name]
		post[:SHIP_LNAME] = address[:last_name] if address[:last_name]
		post[:SHIP_MTHD_CD] = address[:method] if address[:method]
		post[:SHIP_ADDR1] = address[:address] if address[:address]
		post[:SHIP_CITY] = address[:city] if address[:city]
		post[:SHIP_STPR_CD] = address[:state] if address[:state]
		post[:SHIP_POSTAL_CD] = address[:zip] if address[:zip]
		post[:SHIP_CNTRY_CD] = address[:contry] if address[:contry]
	  end
	  
	  def add_address(post, options)
		address = (options[:billing_address] || {})
		
		post[:CARD_AVS_ADDR] = address[:address] if address[:address]
		post[:CARD_AVS_ZIPCODE] = address[:zip] if address[:zip]
	  end

      def add_payment(post, payment, options)
		post[:CARD_NUM] = payment.number
        post[:CARD_OWN] = payment.name
		post[:CARD_EXP_DT] = sprintf("%02d", payment.month)+payment.year.to_s[-2,2]
        post[:CARD_CVV] = payment.verification_value
		post[:CARD_TYPE] = card_brand(payment)
		add_address(post, options)
      end

      def parse(body)
		return {} unless body
        JSON.parse(body)
      end

      def commit(url_action, parameters)
		success = false
		message = ""
        url = (test? ? test_url : live_url) + url_action
        raw_response = ssl_post(url, post_data(parameters))
		begin
          response = parse(raw_response)
		  success = true if ((response["ID"] && response["AUTH_CODE"]) || (response["folio"] && (response["status"] == "ok")))
		rescue JSON::ParserError
          response = json_error(raw_response)
		end
		
		if success 
			message = "success"
		else
			message = (response["ERROR_MSG"] || "")
		end

		Response.new(success, message, response,
          :test => test?,
          :authorization => authorization_from(response),
          :fraud_review => fraud_review?(response)
        )
      end
	  
      def fraud_review?(response)
		(response["ERROR_CODE"] && (response["ERROR_CODE"] == "500")) || false
      end
	  
	  def authorization_from(response)
		(response["AUTH_CODE"] || response["folio"] || "") 
	  end

      def post_data(parameters = {})
		parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
	  
	  def json_error(raw_response)
		msg = 'Invalid response received from the Banwire API.  Please contact Banwire support if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "ERROR_MSG" => msg
        }
	  end
    end
  end
end
