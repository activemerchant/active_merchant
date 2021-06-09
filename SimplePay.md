# Simple Pay Gateway

## Usecases:

The gateway provides two different methods for bank transactions. One when the response contains a redirect URL, where the users can fulfill tthe transaction by providing their card data.

Initialize the gateway

```ruby
require 'active_merchant'

#Enable testing mode.
ActiveMerchant::Billing::Base.mode = :test 

#redirectURL: is the url, where the users will be redirected after the transactions
#timeout: Time interval (in minutes) till the transaction can be completed.
gateway = ActiveMerchant::Billing::SimplePayGateway.new(
    :merchantID  => 'PUBLICTESTHUF',
    :merchantKEY => 'FxDa5w314kLlNseq2sKuVwaqZshZT5d6',
    :redirectURL => 'https://www.myawesomewebsite.com/redirect-back',
    :timeout     => 30
)

# OR you can provide multiple urls, depending on the transaction status

gateway = ActiveMerchant::Billing::SimplePayGateway.new(
    :merchantID  => 'PUBLICTESTHUF',
    :merchantKEY => 'FxDa5w314kLlNseq2sKuVwaqZshZT5d6',
    :urls => {
        :success => 'https://www.myawesomewebsite.com/success',
        :fail    => 'https://www.myawesomewebsite.com/fail',
        :cancel  => 'https://www.myawesomewebsite.com/cancel',
        :timeout => 'https://www.myawesomewebsite.com/timeout'
    },
    :timeout     => 30
)
```