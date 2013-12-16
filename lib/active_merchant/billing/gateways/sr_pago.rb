begin
  require 'xmlsimple'
rescue LoadError
  # nothing to do
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SrPagoGateway < Gateway
      self.test_url = 'https://www.srpago.com/validaciones/'
      self.live_url = 'https://www.srpago.com/red/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['MX']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]

      # The homepage URL of the gateway
      self.homepage_url = 'https://senorpago.com'

      # The name of the gateway
      self.display_name = 'Sr.Pago'

      self.default_currency = 'MXP'

      def initialize(options = {})
        #requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end

      #UID parameter is mandatory, if you don´t know which is your uid
      #please contact a 'Sr.Pago' advisor
      def purchase(money, creditcard, options = {})
	puts cardType(card_brand(creditcard).to_s)
        post = {
		:wapps  	=> "WPOS",
		:XML    	=> "SI",
    		:ecom_id	=> options[:uid],
		:acc		=> "Guardar",
    		:Referencia	=> "Cargo de prueba",
    		:Importe	=> amount(money),
    		:TipoTarjeta	=> cardType(card_brand(creditcard))
	}
	if options[:test].eql?(true)
		post[:test] = options[:test]
	end

        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end

      private

      def add_customer_data(params, options)
	params[:email] = options[:email] unless options[:email].blank?
	params[:ip] = options[:ip] unless options[:ip].blank?
      end

      def add_address(params, creditcard, options)
        address = options[:billing_address] || options[:address]

        if address
          params[:address1] = address[:address1] unless address[:address1].blank?
          params[:address2] = address[:address2] unless address[:address2].blank?
          params[:city] = address[:city] unless address[:city].blank?
          params[:state] = address[:state] unless address[:state].blank?
          params[:zip] = address[:zip] unless address[:zip].blank?
          params[:country] = address[:country] unless address[:country].blank?
          params[:avs] = 'n'
        end

        if shipping_address = options[:shipping_address]
          params[:shipto_name] = shipping_address[:name] unless shipping_address[:name].blank?
          params[:shipto_address1] = shipping_address[:address1] unless shipping_address[:address1].blank?
          params[:shipto_address2] = shipping_address[:address2] unless shipping_address[:address2].blank?
          params[:shipto_city] = shipping_address[:city] unless shipping_address[:city].blank?
          params[:shipto_state] = shipping_address[:state] unless shipping_address[:state].blank?
          params[:shipto_zip]         = shipping_address[:zip] unless shipping_address[:zip].blank?
          params[:shipto_country] = shipping_address[:country] unless shipping_address[:country].blank?
        end
      end

      def add_invoice(post, options)

      end

      def add_creditcard(params, creditcard)
        params[:media] = "cc"
        params[:Nombre] = creditcard.name
        params[:NoTarjeta] = creditcard.number
        params[:exp] = expdate(creditcard)
	params[:Mes] = sprintf("%.2i", creditcard.month)
	params[:Agnio] = creditcard.year.to_s
        params[:CodigoSeguridad] = creditcard.verification_value if creditcard.verification_value?
      end

      def parse(body)
	result = XmlSimple.xml_in(body.to_s)
	pay = result["PAGO"]
	response = {}
	pay.each do |element|
		element.each do |key, value|
			#puts "key: #{key}- value: #{value[0]}"
			response[:"#{key}"] = "#{value[0]}"
		end
	end
	
	response
      end

      def commit(action, money, parameters)
	url = if parameters[:test].eql?(true)
		self.test_url
	else
		self.live_url
	end
	parameters.delete(:test)

	stringify_params(parameters)
	puts extractParams(parameters)

	data = parse(ssl_post(url, extractParams(parameters)))
	if data[:ESTADO].eql?("OK")
		success = true
		message = data[:COMERCIO]
		authorization = data[:AUTHNO]
		cvv = nil
		avs = data[:FOLIO]
	else
		success = false
		message = data[:AUTHNO]
		authorization = nil
		cvv = nil
		avs = nil
	end
	
	puts data

        Response.new(success, message, data,
          :test => true,
          :authorization => authorization,
          :cvv_result => cvv,
          :avs_result => { :code => avs }
        )
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
	parameters.collect{|key, value| "#{key}=#{CGI.escape(value.to_s)}"}.join("&")
      end

      def extractParams(parameters)
	params = ""
	if parameters.respond_to?("each")
		parameters.each do |key, value|
			params = "#{params}#{key}=#{CGI.escape(value)}&"
		end
	end
	params
      end

      def stringify_params (parameters)
	parameters.keys.reverse.each do |key|
		if parameters[key]
			parameters[key.to_s] = parameters[key]
		end
		parameters.delete(key)
	end
      end

      def expdate(creditcard)
        year = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def cardType(type)
	returned = case type
	when "visa"
		"VISA"
	when "master"
		"MAST"
	end
      end

    end
  end
end

