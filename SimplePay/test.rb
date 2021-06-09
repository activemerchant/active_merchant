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

# res = gateway.purchase({
#     :ammount => 2000,
#     :email => 'email@email.hu',
#     :threeDSReqAuthMethod => '01', #???
#     :address => {
#         :name =>  'myname',
#         :company => 'company',
#         :country => 'HU',
#         :state => 'Budapest',
#         :city => 'Budapest',
#         :zip => '1111',
#         :address1 => 'Address u.1',
#         :address2 => 'Address u.2',
#         :phone => '06301111111'
#     },
#     :items => [     #optional
#         {
#         :ref => "Product ID 2",
#         :title => "Product name 2",
#         :description => "Product description 2",
#         :amount => "2",
#         :price => "5",
#         :tax => "0"
#         }
#     ]
# })

# res = gateway.authorize({
#     :ammount => 2000,
#     :email => 'email@email.hu',
#     :threeDSReqAuthMethod => '01', #???
#     :address => {
#         :name =>  'myname',
#         :company => 'company',
#         :country => 'HU',
#         :state => 'Budapest',
#         :city => 'Budapest',
#         :zip => '1111',
#         :address1 => 'Address u.1',
#         :address2 => 'Address u.2',
#         :phone => '06301111111'
#     },
#     :items => [     #optional
#         {
#         :ref => "Product ID 2",
#         :title => "Product name 2",
#         :description => "Product description 2",
#         :amount => "2",
#         :price => "5",
#         :tax => "0"
#         }
#     ]
# })

# res = gateway.capture({
#     :orderRef = 'someRef',
#     :originalTotal => 2000,
#     :approveTotal => 1800
# })

# res = gateway.refund({
#     :orderRef = 'someRef',
#     :refundTotal => 2000
# })

# res = gateway.query({
#     :transactionIds = ['id1', 'id2'],
#     :detailed = true,   #optional
#     :refunds = true     #optional
# })

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
    :ammount => 2000,
    :email => 'email@email.hu',
    :threeDS => {
        :threeDSReqAuthMethod => '01', #???
        :threeDSReqAuthType => 'CIT', #??? W: CIT WO:MIT rec : REC
        :browser => {   #IF CIT
            :accept => '',
            :agent => '',
            :ip => '127.0.01',
            :java => 'navigator.javaEnabled()',
            :lang => 'navigator.language',
            :color => 'screen.colorDepth',
            :height => 'screen.height',
            :width => 'screen.width',
            :tz => ' new Date().getTimezoneOffset()',
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
    },
    :threeDSExternal => {
        :xid => "01234567980123456789",
        :eci => "01",
        :cavv => "ABCDEF"
    }
})

puts res.message
puts res.error_code
