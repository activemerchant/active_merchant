require 'rubygems'
$:.unshift(File.dirname(__FILE__) + './lib')
require 'money'
require 'active_merchant'

# Using the money library, passing the amount in cents
tendollar = Money.us_dollar(1000)

# Using an approved TC test card
creditcard = ActiveMerchant::Billing::CreditCard.new({
	:number => '4111111111111111',
	:month => 8,
	:year => 2006,
	:name => 'Longbob Longsen',
})

gateway = ActiveMerchant::Billing::Base.gateway(:trust_commerce).new(:login => "TestMerchant", :password => "password")

response = gateway.authorize(tendollar, creditcard)

puts "Success: " + response.success?.to_s
puts "Message: " + response.message
puts "TransID: " + response.params["transid"].to_s
