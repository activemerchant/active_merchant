require 'json'

require 'net/http'
require 'uri'
@uri = URI.parse('https://api.sandbox.veritrans.co.id/v2/token?card_number=4811111111111114&card_cvv=123&card_exp_month=01&card_exp_year=2020&client_key=VT-client-ZiKr3dq3HTywXpZP&')

require 'veritrans'
Midtrans.config.client_key = 'VT-client-ZiKr3dq3HTywXpZP'
Midtrans.config.server_key = 'VT-server-Jk750sVuDY9Gz3iBlulfUthr'
info_object = {
  "payment_type" => "credit_card",
  "transaction_details" => {
    "order_id" => "C17551",
    "gross_amount" => 40
  },
  "credit_card" => {
  },
  "item_details" => [{
    "id" => "a1",
    "price" => 20,
    "quantity" => 2,
    "name" => "Apel",
    "brand" => "Fuji Apple",
    "category" => "Fruit",
    "merchant_name" => "Fruit-store"
  }],
  "customer_details" => {
    "first_name" => "Luu",
    "last_name" => "Nguyen",
    "email" => "luu.nguyen@honestbee.com",
    "phone" => "+6582431164",
    "billing_address" => {
      "first_name" => "Luu",
      "last_name" => "Nguyen",
      "email" => "luu.nguyen@honestbee.com",
      "phone" => "+6582431164",
      "address" => "2 Alexandra Road, Singapore 159919",
      "city" => "Singapore",
      "postal_code" => "159919",
      "country_code" => "SGP"
    },
    "shipping_address" => {
      "first_name" => "Luu",
      "last_name" => "Nguyen",
      "email" => "luu.nguyen@honestbee.com",
      "phone" => "+6582431164",
      "address" => "2 Alexandra Road, Singapore 159919",
      "city" => "Singapore",
      "postal_code" => "159919",
      "country_code" => "SGP"
    }
  }
}

def get_token_id
  response = Net::HTTP.get_response(@uri)
  body = response.body.scan(/Veritrans.c\((.*?)\);/).first.first
  return JSON.parse(body)['token_id']
end

require 'securerandom'

puts "***** Charge directly *****"
info_object1 = info_object.dup
info_object1['transaction_details']['order_id'] = SecureRandom.uuid
info_object1['credit_card']['token_id'] = get_token_id
payment_response = Midtrans.charge(payment_type: info_object1['payment_type'], transaction_details: info_object1['transaction_details'], credit_card: info_object1['credit_card'], item_details: info_object1['item_details'], customer_details: info_object1['customer_details'])
puts "***** Charge directly response *****"
puts payment_response.inspect


puts "***** Authorization *****"
info_object2 = info_object.dup
info_object2['credit_card']['type'] = 'authorize'
info_object2['transaction_details']['order_id'] = SecureRandom.uuid
info_object2['credit_card']['token_id'] = get_token_id
payment_response = Midtrans.charge(payment_type: info_object2['payment_type'], transaction_details: info_object2['transaction_details'], credit_card: info_object2['credit_card'], item_details: info_object2['item_details'], customer_details: info_object2['customer_details'])
puts "***** Authorization response *****"
puts payment_response.inspect

puts "***** Capture *****"
payment_response = Midtrans.capture(payment_response.data[:transaction_id], payment_response.data[:gross_amount])
puts "***** Capture response *****"
puts payment_response.inspect

