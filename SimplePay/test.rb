require 'active_merchant'
require '../lib/active_merchant/billing/gateways/simple_pay.rb'

ActiveMerchant::Billing::Base.mode = :test

gateway = ActiveMerchant::Billing::SimplePayGateway.new({
    :merchantID  => 'PUBLICTESTHUF',
    :merchantKEY => 'FxDa5w314kLlNseq2sKuVwaqZshZT5d6',
    :redirectURL => 'https://127.0.0.1',
    :timeout     => 30,
    :returnRequest => true
})

puts ActiveMerchant::Billing::SimplePayGateway.allowed_ip

puts ActiveMerchant::Billing::SimplePayGateway.utilbackref('https://sdk.simplepay.hu/back.php?r=eyJyIjowLCJ0Ijo5OTg0NDk0MiwiZSI6IlNVQ0NFU1MiLCJtIjoiUFVCTElDVEVTVEhVRiIsIm8iOiIxMDEwMTA1MTU2ODAyOTI0ODI2MDAifQ%3D%3D&s=El%2Fnvex9TjgjuORI63gEu5I5miGo4CSAD5lmEpKIxp7WuVRq6bBeh1QdyEvVGSsi')

## Possible URLS
#:urls => {
#    :success => 'https://sdk.simplepay.hu/success.php',
#    :fail    => 'https://sdk.simplepay.hu/fail.php',
#    :cancel  => 'https://sdk.simplepay.hu/cancel.php',
#    :timeout => 'https://sdk.simplepay.hu/timeout.php'
#}

res = gateway.purchase({
    :orderRef => 'forthequerymethod',
    :amount => 2000,
    :email => 'email@email.hu',
    :address => {
        :name =>  'myname',
        :company => 'company',
        :country => 'HU',
        :state => 'Budapest',
        :city => 'Budapest',
        :zip => '1111',
        :address1 => 'Address u.1',
        :address2 => 'Address u.2',
        :phone => '06301111111'
    },
    :items => [
        {
        :ref => "Product ID 2",
        :title => "Product name 2",
        :description => "Product description 2",
        :amount => "2",
        :price => "5",
        :tax => "0"
        }
    ],
    :threeDSReqAuthMethod => '01',
    :maySelectEmail => true,
    :maySelectInvoice => true,
    :maySelectDelivery => ["HU","AT","DE"]
})

# :delivery => [
#     {
#     :name => "SimplePay V2 Tester",
#     :company => "Company name",
#     :country => "hu",
#     :state => "Budapest",
#     :city => "Budapest",
#     :zip => "1111",
#     :address => "Delivery address",
#     :address2 => "",
#     :phone => "06203164978"
#     }
# ],

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"

res = gateway.purchase({
    :amount => 2000,
    :email => 'email@email.hu',
    :cardSecret => 'thesuperdupersecret',
    :address => {
        :name =>  'myname',
        :company => 'company',
        :country => 'HU',
        :state => 'Budapest',
        :city => 'Budapest',
        :zip => '1111',
        :address1 => 'Address u.1',
        :address2 => 'Address u.2',
        :phone => '06301111111'
    },
})

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"

res = gateway.authorize({
    :orderRef => 'authorderref',
    :amount => 2000,
    :email => 'email@email.hu',
    :address => {
        :name =>  'myname',
        :company => 'company',
        :country => 'HU',
        :state => 'Budapest',
        :city => 'Budapest',
        :zip => '1111',
        :address1 => 'Address u.1',
        :address2 => 'Address u.2',
        :phone => '06301111111'
    }
})

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"

res = gateway.capture({
    :orderRef => 'authorderref',
    :originalTotal => 2000,
    :approveTotal => 1800
})

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"

res = gateway.refund({
    :orderRef => 'authorderref',
    :refundTotal => 200
})

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"


## OR orderRefs
res = gateway.query({
    :transactionIds => ['501167933'],
})

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"

credit_card = ActiveMerchant::Billing::CreditCard.new(
  :number     => '4908366099900425',
  :month      => '10',
  :year       => '2021',
  :first_name => 'v2 AUTO',
  :last_name  => 'Tester',
  :verification_value  => '579'
)


res = gateway.auto({
    :credit_card => credit_card,
    :amount => 2000,
    :email => 'email@email.hu',
    :threeDS => {
        :threeDSReqAuthMethod => '01', 
        :threeDSReqAuthType => 'MIT',
    },
    :address => {
        :name =>  'myname',
        :company => 'company',
        :country => 'HU',
        :state => 'Budapest',
        :city => 'Budapest',
        :zip => '1111',
        :address1 => 'Address u.1',
        :address2 => 'Address u.2',
        :phone => '06301111111'
    }
})

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"