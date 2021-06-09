# Simple Pay Gateway

## Usecases:

The gateway provides **two different methods** for bank transactions. One when the response contains a redirect URL, where the users can fulfill tthe transaction by providing their card data.

### Initialize the gateway:

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

The gateways provides these methods for making transactions
    
* [purchase()](#purchase)
* [authorize()](#authorize)
* [capture()](#capture)
* [refund()](#refund)
* [query()](#query)
* [auto()](#auto)

## Responses

The response contains all the information about the transaction, in the reponses message.
```ruby
res.message
```

### **purchase()**

After sucessfull call, the response message will contain a *:redirectURL*, where the customer should be redirected, to finish the transaction.

In case if collecting the card data, transaction is possible without redirection.
[See auto method](#auto)

```ruby
res = gateway.purchase({
    :ammount => 2000,
    :email => 'customer@email.hu',
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
    # Optionally you can define items for the transaction.
    # If both :ammount, and :items are present, :ammount will be ignored.
    :items => [
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
```

### **auto()**

**DISCLAIMER!**
**The merchant system must achieve audited PCI-DSS compliance, too.**
**Please don’t develop this function if your system does not meet these requirements.**

threeDSReqAuthMethod: 
* 01 - guest
* 02 - registered with the merchant
* 05 - registered with a third party ID (Google, Facebook, account, etc.) 

threeDSReqAuthType: 
* CIT - The customer is present.
* MIT - The customer is not present.
* REC - Recurring payment.

In case of **CIT** type *:browser* is requiered and the response could contain a redirectURL for the challange.

In case of MIT or REC the *:browser*, should not be included.

```ruby
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
    :email => 'customer@email.hu',
    :threeDS => {
        :threeDSReqAuthMethod => '01', 
        :threeDSReqAuthType => 'CIT',
        :browser => {
            :accept => '',
            :agent => '',
            :ip => '127.0.01',
            :java => 'navigator.javaEnabled()',
            :lang => 'navigator.language',
            :color => 'screen.colorDepth',
            :height => 'screen.height',
            :width => 'screen.width',
            :tz => ' new Date().getTimezoneOffset()',
        }
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
```

threeDSExternal:
It is possible to use external 3DS challange option, insead of *:threeDS*.

* xid - XID, unique identifier generated for the identification request
* eci - ECI (e-commerce indicator) the security level of the transaction which can be received in the form returned by the MPI )
* cavv - CAVV/AAV/AEV, a cryptogram verifying identification or an attempted identification, in raw format

```ruby
:threeDSExternal => {
    :xid => "01234567980123456789",
    :eci => "01",
    :cavv => "ABCDEF"
}
```

### **authorize()**

As same as the **purchase()** method, except the transaction won't happen until the capture is called.

### **capture()**

* *:orderRef* - On successfull authorization the response's message containt the reference number.
* *:originalTotal* - The authorized ammount
* *:approveTotal* - The ammount should be captured

```ruby
res = gateway.capture({
    :orderRef = 'someRef',
    :originalTotal => 2000,
    :approveTotal => 1800
})
```

### **refund()**

* *:orderRef* - On successfull authorization the response's message containt the reference number.
* *:refundTotal* - The ammount that should be refunded.

```ruby
res = gateway.refund({
    :orderRef = 'someRef',
    :refundTotal => 2000
})
```

### **query()**

* *:transactionIds* - Transaction id's that we are querying for.
* *:detailed* - Do we need detailed informations?
* *:refunds* - Are refunds should be included?

```ruby
res = gateway.query({
    :transactionIds = ['id1', 'id2'],
    :detailed = true,   #optional
    :refunds = true     #optional
})
```