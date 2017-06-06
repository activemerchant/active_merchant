module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CcavenueMcpgGateway < Gateway
      self.test_url = 'https://test.ccavenue.com/transaction/transaction.do?command=initiateTransaction'
      self.live_url = 'https://secure.ccavenue.com/transaction/transaction.do?command=initiateTransaction'
	  
      self.supported_countries = ['IN']
      self.default_currency = 'INR'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club]

      self.homepage_url = 'https://www.ccavenue.com/'
      self.display_name = 'CCAvenue'

      
      def initialize(options={})
        requires!(options, :merchant_id, :working_key, :access_code)
        super
      end

      def purchase(money, payment, options={})
        post = {}
		
		add_parameters(post)
		add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        commit(post)
      end

      private
	  
	  def add_parameters(post)
		 post[:merchant_id] = @options[:merchant_id]
		 post[:working_key] = @options[:working_key]
		 post[:access_code] = @options[:access_code]
	  end
	  
      def add_address(post, options)
	    if options[:billing_address]
          post[:billing_name] = options[:billing_address][:name]
          post[:billing_address] = options[:billing_address][:address1]<<", "<<options[:billing_address][:address2]
          post[:billing_city] = options[:billing_address][:city]
          post[:billing_state] = options[:billing_address][:state]
          post[:billing_zip] = options[:billing_address][:zip]
          post[:billing_country] = options[:billing_address][:country]
		  post[:billing_tel] = options[:billing_address][:phone]
        end

        if options[:shipping_address]
          post[:delivery_name] = options[:shipping_address][:name]
          post[:delivery_address] = options[:shipping_address][:address1]<<", "<<options[:shipping_address][:address2]
          post[:delivery_city] = options[:shipping_address][:city]
          post[:delivery_state] = options[:shipping_address][:state]
          post[:delivery_zip] = options[:shipping_address][:zip]
          post[:delivery_country] = options[:shipping_address][:country]
          post[:delivery_tel] = options[:shipping_address][:phone]
        end
      end

      def add_invoice(post, money, options)
		post[:order_id]= options[:order_id]
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)		
		post[:card_name] = payment.brand
        post[:card_number] = payment.number
        post[:expiry_month] = format(payment.month, :two_digits)
        post[:expiry_year] = format(payment.year, :four_digits)
        post[:cvv_number] = payment.verification_value
      end
	  
	  def add_customer_data(post, options)
		 post[:billing_email] = options[:email] || "email"
	  end

      def commit(parameters={})
        url = (test? ? test_url : live_url)
		key =parameters[:working_key]
		urlString=post_data(parameters)		
		enc_response = ssl_post(url,urlString)			
		response = decrypt(enc_response,key)		
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?        
        )
      end

      def success_from(response)
		response["order_status"]=="Success" #true else false will be returned
      end

      def message_from(response)
		  result=response["order_status"]
		  if result=="Success"
			 return_string ="Your order is Successful"
	      elsif result=="Failure"
			return_string ="Your order is Unsuccessful"
		  elsif result=="Aborted"
			return_string ="Your transaction is Aborted"
		  end
		return return_string
	  end

      def authorization_from(response) 
		response["tracking_id"]
      end

	  INIT_VECTOR = (0..15).to_a.pack("C*") 
	  
	  # code for creating encrypted request
      def post_data(parameters = {})
		  plain_text = create_plain_text(parameters);
		  key = parameters[:working_key]
		  secret_key =  [Digest::MD5.hexdigest(key)].pack("H*") 
		  cipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
		  cipher.encrypt
		  cipher.key = secret_key
		  cipher.iv  = INIT_VECTOR
		  encrypted_text = cipher.update(plain_text) + cipher.final
		  final_enc_text =(encrypted_text.unpack("H*")).first
		  temphash={}
		  temphash["encRequest"]=final_enc_text
		  temphash["access_code"]=parameters[:access_code]
		  tempString=temphash.map{|k,v| "#{k}=#{v}"}.join('&') 
		 
		  return tempString
      end
	  
	  
	  def create_plain_text(parameters={})
	    tempString=parameters.map{|k,v| "#{k}=#{v}"}.join('&')
		return tempString
	  end
	  
	  def decrypt(cipher_text,key)
		  secret_key =  [Digest::MD5.hexdigest(key)].pack("H*")
		  encrypted_text = [cipher_text].pack("H*")
		  decipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
		  decipher.decrypt
		  decipher.key = secret_key
		  decipher.iv  = INIT_VECTOR
		  decrypted_text = (decipher.update(encrypted_text) + decipher.final).gsub(/\0+$/, '')
		  
		  #code for splitting text and creating hash of response key and values
		  decryptedArray = decrypted_text.split("&")
		  
		  tempResponseHash={}
		  
		  decryptedArray.each do |pair|				
				pairArray=pair.split("=")
				tempResponseHash[pairArray[0]]=pairArray[1].to_s				
		  end			 
		  return tempResponseHash
	  end
	    
    end
  end
end
