#                                                    #
# ruby -I test test/unit/gateways/simple_pay_test.rb #
#                                                    #

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
        :address => 'Address u.1',
        :address2 => 'Address u.2',
        :phone => '06301111111'
    },
    :recurring => {
        :times => 1,
        :until => "2022-12-01T18:00:00+02:00",
        :maxAmount => 2000
    }
})

puts "\n\n"
puts res.success?
puts res.message
puts "\n\n"
puts "-----------------------------------------"

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

# res = gateway.purchase({
#     :amount => 2000,
#     :email => 'email@email.hu',
#     :cardSecret => 'thesuperdupersecret',
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
# })

# puts "\n\n"
# puts res.success?
# puts res.message
# puts "\n\n"
# puts "AUTH-----------------------------------------"

# res = gateway.authorize({
#     :orderRef => 'authorderref',
#     :amount => 2000,
#     :email => 'email@email.hu',
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
#     }
# })

# puts "\n\n"
# puts res.success?
# puts res.message
# puts "\n\n"
# puts "-----------------------------------------"

# res = gateway.capture({
#     :orderRef => 'authorderref',
#     :originalTotal => 2000,
#     :approveTotal => 1800
# })

# puts "\n\n"
# puts res.success?
# puts res.message
# puts "\n\n"
# puts "-----------------------------------------"

# res = gateway.refund({
#     :orderRef => 'authorderref',
#     :refundTotal => 200
# })

# puts "\n\n"
# puts res.success?
# puts res.message
# puts "\n\n"
# puts "-----------------------------------------"


## OR orderRefs
# res = gateway.query({
#     :transactionIds => ['501167933'],
# })

# puts "\n\n"
# puts res.success?
# puts res.message
# puts "\n\n"
# puts "-----------------------------------------"

# credit_card = ActiveMerchant::Billing::CreditCard.new(
#   :number     => '4908366099900425',
#   :month      => '10',
#   :year       => '2021',
#   :first_name => 'v2 AUTO',
#   :last_name  => 'Tester',
#   :verification_value  => '579'
# )


# res = gateway.auto({
#     :credit_card => credit_card,
#     :amount => 2000,
#     :email => 'email@email.hu',
#     :threeDS => {
#         :threeDSReqAuthMethod => '01', 
#         :threeDSReqAuthType => 'MIT',
#     },
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
#     }
# })

# puts "\n\n"
# puts res.success?
# puts res.message
# puts "\n\n"
# puts "-----------------------------------------"