require 'active_merchant'
require '../lib/active_merchant/billing/gateways/simple_pay.rb'

ActiveMerchant::Billing::Base.mode = :test

gateway = ActiveMerchant::Billing::SimplePayGateway.new(
    :merchantID  => 'PUBLICTESTHUF',
    :merchantKEY => 'FxDa5w314kLlNseq2sKuVwaqZshZT5d6',
    :redirectURL => 'https://127.0.0.1',
    :timeout     => 30
)

## Possible URLS
#:urls => {
#    :success => 'https://sdk.simplepay.hu/success.php',
#    :fail    => 'https://sdk.simplepay.hu/fail.php',
#    :cancel  => 'https://sdk.simplepay.hu/cancel.php',
#    :timeout => 'https://sdk.simplepay.hu/timeout.php'
#}

res = gateway.purchase({
    :ammount => 2000,
    :email => 'email@email.hu',
    :threeDSReqAuthMethod => '01', #???
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
    :items => [     #optional
        {
        :ref => "Product ID 2",
        :title => "Product name 2",
        :description => "Product description 2",
        :amount => "2",
        :price => "5",
        :tax => "0"
        }
    ]
})

res = gateway.authorize({
    :ammount => 2000,
    :email => 'email@email.hu',
    :threeDSReqAuthMethod => '01', #???
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
    :items => [     #optional
        {
        :ref => "Product ID 2",
        :title => "Product name 2",
        :description => "Product description 2",
        :amount => "2",
        :price => "5",
        :tax => "0"
        }
    ]
})

res = gateway.capture({
    :orderRef = 'someRef',
    :originalTotal => 2000,
    :approveTotal => 1800
})

res = gateway.refund({
    :orderRef = 'someRef',
    :refundTotal => 2000
})

res = gateway.query({
    :transactionIds = ['id1', 'id2'],
    :detailed = true,   #optional
    :refunds = true     #optional
})

puts res.message
puts res.error_code
puts res.params['paymentUrl']