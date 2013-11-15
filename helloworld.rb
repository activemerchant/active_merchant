require 'rubygems'
require 'active_merchant'

# Use the TrustCommerce test servers
ActiveMerchant::Billing::Base.mode = :test

gateway = ActiveMerchant::Billing::CardStreamModernGateway.new(
    :login => '100001',
    :password => 'Circle4Take40Idea')

# ActiveMerchant accepts all amounts as Integer values in cents
amount = 1000 # $10.00

# The card verification value is also known as CVV2, CVC2, or CID
credit_card = ActiveMerchant::Billing::CreditCard.new(
    :first_name => 'Bob',
    :last_name => 'Bobsen',
    :number => '4242424242424242',
    :month => '8',
    :year => Time.now.year+1,
    :verification_value => '000')

# Validating the card automatically detects the card type
if credit_card.valid?
  # Capture $10 from the credit card
  response = gateway.purchase(amount, credit_card, {:order_id => 1,
                                                    :billing_address => {
                                                        :address1 => 'The Parkway',
                                                        :address2 => "Larches Approach",
                                                        :city => "Hull",
                                                        :state => "North Humberside",
                                                        :zip => 'HU7 9OP'
                                                    }
  })

  if response.success?
    puts "Successfully charged $#{sprintf("%.2f", amount / 100)} to the credit card #{credit_card.display_number}"
  else
    raise StandardError, response.message
  end
end

