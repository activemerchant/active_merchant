# Simple Pay Gateway

## Usage:

The gateway provides **two different methods** for bank transactions. One when the response contains a redirect URL, where the users can fulfill the transaction by providing their card data.

### Initialize the gateway:

* *:redirectURL* - The url, where the users will be redirected after the transactions
* *:timeout* - Time interval (in minutes) till the transaction can be completed.
* *:currency* - Transactions currency. Avaiable choices ['HUF', 'EUR', 'USD'].

```ruby
require 'active_merchant'

#Enable testing mode. ( SANDBOX )
ActiveMerchant::Billing::Base.mode = :test 

gateway = ActiveMerchant::Billing::SimplePayGateway.new(
    :merchantID  => 'PUBLICTESTHUF',
    :merchantKEY => 'FxDa5w314kLlNseq2sKuVwaqZshZT5d6',
    :redirectURL => 'https://www.myawesomewebsite.com/redirect-back',
    :timeout     => 30,
    :currency    => 'HUF'
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

* One time payments  
    * [purchase()](#purchase)
    * [authorize()](#authorize)
    * [capture()](#capture)
    * [refund()](#refund)
    * [query()](#query)
    * [auto()](#auto)

* Recurring payments
    * [dorecurring()](#dorecurring)
    * [do()](#do)
    * [tokenquery()](#tokenquery)
    * [cardquery()](#cardquery)
    * [tokencancel()](#tokencancel)
    * [cardcancel()](#cardcancel)

### Responses

The response contains all the information about the transaction, in the reponses message. The responses are JSON strings wilth all the information about the transaction.
```ruby
res.message
```

On error the response message will contain the error message.

## Methods

### **purchase()**

After sucessfull call, the response message will contain a *:redirectURL*, where the customer should be redirected, to finish the transaction.

In case if collecting the card data, transaction is possible without redirection.
[See auto method](#auto)

**This is the least amount of information you will need to start a transaction.**
**Later on they will be refered as # MANDATORY FIELDS...**

```ruby
res = gateway.purchase({
    :amount => 2000,
    :email => 'customer@email.hu',
    :address => {
        :name =>  'Customer Name',
        :country => 'HU',
        :state => 'Budapest',
        :city => 'Budapest',
        :zip => '1111',
        :address1 => 'Address u.1',
    }
})
```

#### Optional fields:

##### *:orderRef:*

Note: the gateway automaticly generates these numbers, but to ensure they are unique you should privide your own.

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :orderRef => 's0m30rd3r3fg3n3r4t3d'
})
```

##### *:invoice*

* company
* address2
* phone

##### *:items*

If both :amount, and :items are present, :amount will be ignored. 

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :items => [
        {
        :ref => "Product ID 2",
        :title => "Product name 2",
        :description => "Product description 2",
        :amount => "2",
        :price => "5",
        :tax => "0",
        :shippingCost => '1',
        :discount => '3',
        :customer => 'IfDifferentThen [:address][:name]'
        }
    ]
})
```

##### *:delivery*

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :delivery => [
        {
        :name => "SimplePay V2 Tester",
        :company => "Company name",
        :country => "hu",
        :state => "Budapest",
        :city => "Budapest",
        :zip => "1111",
        :address => "Delivery address",
        :address2 => "",
        :phone => "06203164978"
        }
    ]
})
```

##### *:methods*

If the payment method is not *CARD* you can set it in the options.

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :methods => ['WIRE']
})
```

**3DS Requirements**

* customerEmail
* invoice
* name
* country
* state
* city
* zip
* address

If they are not known, you can use *:maySelectEmail* or *:maySelectInvoice* options.

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :maySelectEmail => true,
    :maySelectInvoice => true
})
```

Also you could ask for delivery informations. You will need to specify the countires where delivery is possible.

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :maySelectDelivery => ["HU","AT","DE"]
})
```

If you would like to start a recurring transaction these options must be present.

* *:times* - How many tokens to generate?
* *:until* - Expiary date of the token.
* *:maxAmount* - Max amount to charge with the token.

Tokens will be created and avaiable in the respond's message.

To start a recurring transaction behind the scenes (with a token) [See dorecurring()](#dorecurring)

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :recurring => {
        :times => 1,
        :until => "2022-12-01T18:00:00+02:00",
        :maxAmount => 2000
    }
})
```

This will charge the customer. If you would like to only register the card, add *:onlyCardReg* field to the options:

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :onlyCardReg => true
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

In case of **CIT** type *:browser* is requiered and the response may contain a redirectURL for the challange.

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
    # MANDATORY FIELDS ...
    :credit_card => credit_card,
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
    }
})
```

threeDSExternal:
It is possible to use external 3DS challange option, insead of *:threeDS*.

* xid - XID, unique identifier generated for the identification request
* eci - ECI (e-commerce indicator) the security level of the transaction which can be received in the form returned by the MPI )
* cavv - CAVV/AAV/AEV, a cryptogram verifying identification or an attempted identification, in raw format

```ruby
res = gateway.auto({
    # MANDATORY FIELDS ...
        :threeDSExternal => {
        :xid => "01234567980123456789",
        :eci => "01",
        :cavv => "ABCDEF"
    }
})
```

### **authorize()**

As same as the **purchase()** method, except the transaction won't happen until the capture is called.

### **capture()**

* *:orderRef* - On successfull authorization the response's message containt the reference number.
* *:originalTotal* - The authorized amount
* *:approveTotal* - The amount should be captured

```ruby
res = gateway.capture({
    :orderRef = 'someRef',
    :originalTotal => 2000,
    :approveTotal => 1800
})
```

### **refund()**

* *:orderRef* - On successfull authorization the response's message containt the reference number.
* *:refundTotal* - The amount that should be refunded.

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

### **dorecurring()**

To start a recurring payment, you will need a token, that **haven't been** used yet.
Also *:threeDSReqAuthMethod* and *:type* fields are mandatory, using this method.

```ruby
res = gateway.dorecurring({
    :token => 'SPT82SL7OMG2FI48N27D85KQX3H8MJ3JEQUD643VILLKTLDXRU7EMFPS8FSS3BBD',
    :threeDSReqAuthMethod => '02',
    :type => 'MIT',
    :amount => 2000,
    :email => 'customer@email.hu',
    :address => {
        :name =>  'Customer Name',
        :company => 'Company Name',
        :country => 'HU',
        :state => 'Budapest',
        :city => 'Budapest',
        :zip => '1111',
        :address1 => 'Address u.1',
        :address2 => 'Address u.2',
        :phone => '06301111111'
    },
})
```

### **tokenquery()**

This method is responible for returning the token's status.
* status - If the token is active or not.
* expiry - The date when the token will expire. 

```ruby
res = gateway.tokenquery({
    :token => 'myawesometoken'
})
```

### **tokencancel()**

This method is responsible for cancelling a token.
* token - The token itself.
* status - Status of the token.
* expiry - Date of expiry.

```ruby
res = gateway.tokenquery({
    token => 'myawesometoken'
})
```

**UNDER DEVELOPMENT**

One click transaction methods, with card secret.

### **do()**

```ruby

```

### **cardquery()**

```ruby

```

### **cardcancel()**

```ruby

```