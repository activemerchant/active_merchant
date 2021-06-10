# Simple Pay Gateway

## Usage:

The gateway provides **two different methods** for bank transactions. One when the response contains a redirect URL, where the users can fulfill the transaction by providing their card data.

[For more information about the methods go to Simple Pays website!](https://simplepay.hu/fejlesztoknek/)

### Initialize the gateway:

* *:merchantID* and *:merchantKEY* values are provided by Simple Pay.
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
    :currency    => 'HUF',

    #Otional, defines to return the JSON sent to Simple Pay
    :returnRequest => true
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

## Responses

The response contains all the information about the transaction, in the reponses message. The responses are JSON strings wilth all the information about the transaction.
```ruby
res.message
```

On error the response message will contain the error message.

If *:returnRequest* is set to true in the constructor, the responses message will contain an array.

* [0] element - request JSON
* [1] element - response JSON / Errors

## backRef / redirection

After a transaction is made with redirection, the redirected URL will contain parameters about the transaction.

Example

https://sdk.simplepay.hu/back.php
**?r**=eyJyIjowLCJ0Ijo5OTg0NDk0MiwiZSI6IlNVQ0NFU1MiLCJtIjoiUFVCTElDVEVTVEhVRiIsIm8iOiIxMDEwMTA1MTU2ODAyOTI0ODI2MDAifQ%3D%3D
**&s**=El%2Fnvex9TjgjuORI63gEu5I5miGo4CS
AD5lmEpKIxp7WuVRq6bBeh1QdyEvVGSsi

**r** - base64 encoded json string

```json
{
    "r": "response code", 
    "t": "transaction id / Simple Pay ID ['THIS WILL BE USED FOR THE DO METHOD']",
    "e": "event [SUCESS, FAIL, TIMEOUT, CANCEL]",
    "m": "merchant",
    "o": "orderRef"
}
```

**s** - Signature of the payment.

The *Signature* is a base64 encoded SHA384 HASH.

Use **utilbackref()** util method to get the values in a hash.

```ruby
ActiveMerchant::Billing::SimplePayGateway.utilIPN(json, signature)
```

## IPN

The gateways class provides a util method for checking the IPN's validity.

```ruby
ActiveMerchant::Billing::SimplePayGateway.utilIPN(json, signature)
```

Simple Pay will send you an HTTP POST request as an IPN. The allowed IP address is avaible at:

```ruby
ActiveMerchant::Billing::SimplePayGateway.allowed_ip
```

In the headers there will be a *Signature* key. Call the util method like utilIPN(requestbody, requestheader['Signature'])

## Methods

### **purchase()**

After sucessfull call, the response message will contain a *:redirectURL*, where the customer should be redirected, to finish the transaction.

In case of collecting the card data, transaction is possible without redirection.
[See auto method](#auto)

**This is the least amount of information you will need to start a transaction.**
**Later on they will be refered as # MANDATORY FIELDS...**

**3DS Requirements**

* **customerEmail**
* **invoice**
* **name**
* **country**
* **state**
* **city**
* **zip**
* **address**

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

If both *:amount*, and *:items* are present, *:amount* will be ignored. 

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
        :customer => 'Customer Name' # If different from [:address][:name]
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

If the payment method is not *CARD* you can set it in the options. **WIRE** method is used for transfers.

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :methods => ['WIRE']
})
```

##### *:threeDSReqAuthMethod:*

* **01** - guest
* **02** - registered with the merchant
* **05** - registered with a third party ID (Google, Facebook, account, etc.) 

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :threeDSReqAuthMethod => '01'
})
```

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

#### oneClick payment:

One click mayment is the method for creating a *:cardSecret*, which could be used on the second time to make a transaction. In that case the customer won't be redirected.

**It is forbidden for the merchant to save the card secret.**

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :cardSecret => 'thesuperdupersecret'
})
```

In case of forgotten *:cardSecret* you will need to use [cardcancel()](#cardcancel) method, and reregister the customer.

After the card registration you can use the [do()](#do) method to start a transaction behid the scenes.

#### Start a recurring payment:

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

This method is used to start a transaction without redirecting the customer.

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
})
```

*:threeDSReqAuthMethod* 
* **01** - guest
* **02** - registered with the merchant
* **05** - registered with a third party ID (Google, Facebook, account, etc.) 

*:threeDSReqAuthType*
* **CIT** - The customer is present.
* **MIT** - The customer is not present.
* **REC** - Recurring payment.

In case of **CIT** type *:browser* is requiered and the response may contain a redirectURL for the challange.

In case of **MIT** or **REC** the *:browser*, should not be included.

```ruby
res = gateway.auto({
    # MANDATORY FIELDS ...
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

*:threeDSExternal*
It is possible to use external 3DS challange option, insead of *:threeDS*.

* **xid** - XID, unique identifier generated for the identification request
* **eci** - ECI (e-commerce indicator) the security level of the transaction which can be received in the form returned by the MPI )
* **cavv** - CAVV/AAV/AEV, a cryptogram verifying identification or an attempted identification, in raw format

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

As same as the [**purchase()**](#purchase) method, except the transaction won't happen until the capture is called.

### **capture()**

After successful authorization, capture the money.

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

Method for refunding money.

* *:orderRef* - On successfull authorization the response's message containt the reference number.
* *:refundTotal* - The amount that should be refunded.

```ruby
res = gateway.refund({
    :orderRef = 'someRef',
    :refundTotal => 2000
})
```

### **query()**

The query method makes avaiable for querying fr the transactions. Note that both *:orderRef* and Simple Pay generated "Simple ID" would work.

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
    # MANDATORY FIELDS ...
    :token => 'SPT82SL7OMG2FI48N27D85KQX3H8MJ3JEQUD643VILLKTLDXRU7EMFPS8FSS3BBD',
    :threeDSReqAuthMethod => '02',
    :type => 'MIT',
    }
})
```

### **tokenquery()**

This method is responible for returning the token's status.

* **status** - If the token is active or not.
* **expiry** - The date when the token will expire. 

```ruby
res = gateway.tokenquery({
    :token => 'myawesometoken'
})
```

### **tokencancel()**

This method is responsible for cancelling a token.

* **token** - The token itself.
* **status** - Status of the token.
* **expiry** - Date of expiry.

```ruby
res = gateway.tokenquery({
    :token => 'myawesometoken'
})
```

**UNDER DEVELOPMENT**

One click transaction methods, with card secret.

### **do()**

* *:cardId* - transaction ID provided by SimplePay [For more information see](#backRef)
* *:threeDS* - this field is mandatory for the do() method. [Explained here : do()](#do)

```ruby
res = gateway.purchase({
    # MANDATORY FIELDS ...
    :cardId => 'SimpePayID',
    :cardSecret => 'thesuperdupersecret',
    :threeDS => {
        :threeDSReqAuthMethod => '01', 
        #:threeDSReqAuthType => 'CIT', this will always be CIT since, the customer is present
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

### **cardquery()**

```ruby
res = gateway.cardquery({
    :cardId => 'Simple Pay ID'
    :history => true #DEFAULT false
})
```

### **cardcancel()**

```ruby
res = gateway.cardcancel({
    :cardId => 'Simple Pay ID'
    :history => true #DEFAULT false
})
```