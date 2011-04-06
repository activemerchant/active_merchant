require 'digest/md5'
require 'rexml/document'

module ActiveMerchant #:nodoc:
	module Billing #:nodoc:
		class MerchantWarriorGateway < Gateway

			TOKEN_TEST_URL = 'https://base.merchantwarrior.com/token/'
			TOKEN_LIVE_URL = 'https://api.merchantwarrior.com/token/'

			POST_TEST_URL = 'https://base.merchantwarrior.com/post/'
			POST_LIVE_URL = 'https://api.merchantwarrior.com/post/'

			# The countries the gateway supports merchants from as 2 digit
			# ISO country codes
			self.supported_countries = ['AU']

			# The card types supported by the payment gateway
			self.supported_cardtypes = [:visa, :master, :american_express,
																	:diners_club, :discover]

			# The homepage URL of the gateway
			self.homepage_url = 'http://www.merchantwarrior.com/'

			# The name of the gateway
			self.display_name = 'MerchantWarrior'

			self.money_format = :dollars
			self.default_currency = 'AUD'

			SUCCESS_CODES = ['0']

			def initialize(options = {})
				requires!(options, :merchant_uuid, :api_key, :api_passphrase)
				@options = options
				super
			end

			def test?
				@options[:test] || super
			end

			def purchase(money, creditcard, options = {})
				post = {}
				add_product(post, options)
				add_creditcard(post, creditcard)
				add_address(post, options)
				add_customer_data(post, options)

				commit('processCard', money, post)
			end

			def process_auth(money, creditcard, options = {})
				post = {}
				add_product(post, options)
				add_creditcard(post, creditcard)
				add_address(post, options)
				add_customer_data(post, options)

				commit('processAuth', money, post)
			end

			def credit(money, identification, options = {})
				requires!(options, :credit_amount)
				commit('refundCard', money, {
								 'transactionID' => identification,
								 'refundAmount' => options[:credit_amount]
							 })
			end

			def token_addcard(creditcard)
				month = sprintf '%02d', creditcard.month
				token_commit('addCard', {
										'cardName'	=> creditcard.name,
										'cardNumber' => creditcard.number,
										'cardExpiryMonth' => month,
										'cardExpiryYear' => creditcard.year})
			end

			def token_processcard(money, card_id, card_key, key_replace, options = {})
				post = {}
				add_product(post, options)
				add_address(post, options)
				add_customer_data(post, options)
				post.merge!('cardID' => card_id)
				post.merge!('cardKey' => card_key)
				post.merge!('cardKeyReplace' => key_replace)
				post.merge!('hash' => verification_hash(money))
				post.merge!('transactionAmount' => money.to_s)
				post.merge!('transactionCurrency' => currency(money))
				token_commit('processCard', post)
			end

			def card_replace_key
				seed = "--#{rand(10000)}--#{Time.now}--"; 
				Digest::SHA1.hexdigest(seed)[0,16]
			end

			private

			def verification_hash(money)
				Digest::MD5.
					hexdigest((@options[:api_passphrase].to_s +
										 @options[:merchant_uuid].to_s +
										 money.to_s +
										 (@options[:currency] || currency(money))).downcase)
			end

			def add_customer_data(post, options)
				post.merge!('customerName' => options[:address][:name])
			end

			def add_address(post, options)
				post.merge!('customerCountry' => options[:address][:country],
										'customerState' => options[:address][:state],
										'customerCity' => options[:address][:city],
										'customerAddress' => options[:address][:address1],
										'customerPostCode' => options[:address][:zip])
			end

			def add_product(post, options)
				post.merge!('transactionProduct' => options[:transaction_product])
			end

			def add_creditcard(post, creditcard)
				four_digit_expiry = creditcard.expiry_date.expiration.strftime("%m%y")

				post.merge!('paymentCardNumber' => creditcard.number,
										'paymentCardName' => creditcard.name,
										'paymentCardExpiry' => four_digit_expiry)
			end

			def parse(body)
				xml = REXML::Document.new(body)

				response = {}

				xml.root.elements.to_a.each do |node|
					parse_element(response, node)
				end

				response
			end

			def parse_element(response, node)
				if node.has_elements?
					node.elements.each{|element| parse_element(response, element) }
				else
					response[node.name.underscore.to_sym] = node.text
				end
			end

			def commit(action, money, parameters)
				url = test? ? POST_TEST_URL : POST_LIVE_URL
				data = ssl_post(url, post_data(action, money, parameters))

				response = parse(data)
				Response.new(success?(response), message_from(response), response,
										 :test => test?)
			end

			def token_commit(action, parameters)
				url = test? ? TOKEN_TEST_URL : TOKEN_LIVE_URL
				data = ssl_post(url + "/" + action, token_data(parameters))
				response = parse(data)
				Response.new(success?(response), message_from(response), response,
										 :test => test?)
			end
			
			def token_purchase(action, money, parameters)
				url = test? ? TOKEN_TEST_URL : TOKEN_LIVE_URL
				data = ssl_post(url + "/" + action, token_purchase_data(money, parameters))
				response = parse(data)
				Response.new(success?(response), message_from(response), response,
										 :test => test?)
			end

			def message_from(response)
				response[:responseMessage]
			end

			def success?(response)
				SUCCESS_CODES.include?(response[:response_code])
			end

			def post_data(action, money,parameters = {})
				parameters.merge({
					'method' => action,
					'merchantUUID' => @options[:merchant_uuid],
					'apiKey' => @options[:api_key],
					'hash' => verification_hash(money),
					'transactionAmount' => money.to_s,
					'transactionCurrency' => currency(money),
				}).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
			end
			def token_data(parameters = {})
				parameters.merge({
					'merchantUUID' => @options[:merchant_uuid],
					'apiKey' => @options[:api_key],
				}).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
			end
		end
	end
end
