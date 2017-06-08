require 'activemerchant'

user_info = {
  customerIdExt: 2,
  firstName: "Paulo",
  lastName: "Carvalho",
  zip: "41830510",
  email: "paulo@paulo.com",
  dob: "12/12/2012",
  ssn: "03663575144",
  sex: "M"
}
customer_id = 66748
address = {
  name: "Paulo C",
  address1: "Rua mariquitas 12",
  address2: nil,
  city: "Guaruja",
  state: "BA",
  zip: "41830510",
  country: "BR",
  phone: "",
  email: "",
}
credit_card = ActiveMerchant::Billing::CreditCard.new(
                :first_name         => 'Bob',
                :last_name          => 'Bobsen',
                :number             => '4111111111111111',
                :month              => '8',
                :year               => Time.now.year+1,
                :verification_value => '000')

x = ActiveMerchant::Billing::MaxipagoGateway.new(login: "6476", password: "rd7nswqpj5vpexguohgnahm6", test: true)
y = x.add_customer(user_info)
z = x.store(credit_card, { customer_id: customer_id, address: address})
 
token = "G5hPhYEbPys="

customer_id = 66626

t = ActiveMerchant::Billing::MaxipagoGateway::MaxipagoPaymentToken.new({token: token, customer_id: customer_id})