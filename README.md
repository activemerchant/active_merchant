# Active Merchant
[![Build Status](https://travis-ci.org/activemerchant/active_merchant.svg?branch=master)](https://travis-ci.org/activemerchant/active_merchant)
[![Code Climate](https://codeclimate.com/github/activemerchant/active_merchant.svg)](https://codeclimate.com/github/activemerchant/active_merchant)

Active Merchant is an extraction from the ecommerce system [Shopify](http://www.shopify.com).
Shopify's requirements for a simple and unified API to access dozens of different payment
gateways with very different internal APIs was the chief principle in designing the library.

It was developed for usage in Ruby on Rails web applications and integrates seamlessly
as a Rails plugin, but it also works excellently as a stand alone Ruby library.

Active Merchant has been in production use since June 2006 and is now used in most modern
Ruby applications which deal with financial transactions. It is maintained by the
[Shopify](http://www.shopify.com) and [Spreedly](https://spreedly.com) teams, with much help
from an ever-growing set of contributors.

See [GettingStarted.md](GettingStarted.md) if you want to learn more about using Active Merchant in your
applications.

If you'd like to contribute to Active Merchant, please start with our [contribution guide](CONTRIBUTING.md).

## Installation

### From Git

You can check out the latest source from git:

    git clone git://github.com/activemerchant/active_merchant.git

### From RubyGems

Installation from RubyGems:

```console
gem install activemerchant
```

Or, if you're using Bundler, just add the following to your Gemfile:

```ruby
gem 'activemerchant'
```

## Usage

This simple example demonstrates how a purchase can be made using a person's
credit card details.

```ruby
require 'active_merchant'

# Use the TrustCommerce test servers
ActiveMerchant::Billing::Base.mode = :test

gateway = ActiveMerchant::Billing::TrustCommerceGateway.new(
            :login => 'TestMerchant',
            :password => 'password')

# ActiveMerchant accepts all amounts as Integer values in cents
amount = 1000  # $10.00

# The card verification value is also known as CVV2, CVC2, or CID
credit_card = ActiveMerchant::Billing::CreditCard.new(
                :first_name         => 'Bob',
                :last_name          => 'Bobsen',
                :number             => '4242424242424242',
                :month              => '8',
                :year               => Time.now.year+1,
                :verification_value => '000')

# Validating the card automatically detects the card type
if credit_card.validate.empty?
  # Capture $10 from the credit card
  response = gateway.purchase(amount, credit_card)

  if response.success?
    puts "Successfully charged $#{sprintf("%.2f", amount / 100)} to the credit card #{credit_card.display_number}"
  else
    raise StandardError, response.message
  end
end
```

For more in-depth documentation and tutorials, see [GettingStarted.md](GettingStarted.md) and the
[API documentation](http://www.rubydoc.info/github/activemerchant/active_merchant/).

Emerging ActiveMerchant 3DS conventions are documented in the [Contributing](https://github.com/activemerchant/active_merchant/wiki/Contributing#3ds-options)
guide and [Standardized 3DS Fields](https://github.com/activemerchant/active_merchant/wiki/Standardized-3DS-Fields) guide of the wiki.

## Supported Payment Gateways

The [ActiveMerchant Wiki](https://github.com/activemerchant/active_merchant/wikis) contains a [table of features supported by each gateway](https://github.com/activemerchant/active_merchant/wiki/Gateway-Feature-Matrix).

* [Adyen](https://www.adyen.com/) - US, AT, AU, BE, BG, BR, CH, CY, CZ, DE, DK, EE, ES, FI, FR, GB, GI, GR, HK, HU, IE, IS, IT, LI, LT, LU, LV, MC, MT, MX, NL, NO, PL, PT, RO, SE, SG, SK, SI
* [Authorize.Net CIM](http://www.authorize.net/) - US
* [Authorize.Net](http://www.authorize.net/) - AU, CA, US
* [Axcess MS](http://www.axcessms.com/) - AD, AT, BE, BG, BR, CA, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GB, GI, GR, HR, HU, IE, IL, IM, IS, IT, LI, LT, LU, LV, MC, MT, MX, NL, NO, PL, PT, RO, RU, SE, SI, SK, TR, US, VA
* [Balanced](https://www.balancedpayments.com/) - US
* [Bambora Asia-Pacific](http://www.bambora.com/) - AU, NZ
* [Bank Frick](http://www.bankfrickacquiring.com/) - LI, US
* [Banwire](http://www.banwire.com/) - MX
* [Barclays ePDQ Extra Plus](http://www.barclaycard.co.uk/business/accepting-payments/epdq-ecomm/) - GB
* [Be2Bill](http://www.be2bill.com/) - FR
* [Beanstream.com](http://www.beanstream.com/) - CA, US
* [BluePay](http://www.bluepay.com/) - US
* [Borgun](https://www.borgun.is/) - IS
* [Braintree](https://www.braintreepayments.com) - US, CA, AU, AD, AT, BE, BG, CY, CZ, DK, EE, FI, FR, GI, DE, GR, HU, IS, IM, IE, IT, LV, LI, LT, LU, MT, MC, NL, NO, PL, PT, RO, SM, SK, SI, ES, SE, CH, TR, GB
* [BridgePay](http://www.bridgepaynetwork.com/) - CA, US
* [Cardknox](https://www.cardknox.com/) - US, CA, GB
* [CardSave](http://www.cardsave.net/) - GB
* [CardStream](http://www.cardstream.com/) - GB
* [Cashnet](http://www.higherone.com/) - US
* [Cecabank](http://www.ceca.es/es/) - ES
* [Cenpos](https://www.cenpos.com/) - AD, AI, AG, AR, AU, AT, BS, BB, BE, BZ, BM, BR, BN, BG, CA, HR, CY, CZ, DK, DM, EE, FI, FR, DE, GR, GD, GY, HK, HU, IS, IN, IL, IT, JP, LV, LI, LT, LU, MY, MT, MX, MC, MS, NL, PA, PL, PT, KN, LC, MF, VC, SM, SG, SK, SI, ZA, ES, SR, SE, CH, TR, GB, US, UY
* [CAMS: Central Account Management System](https://www.centralams.com/) - US
* [Checkout.com](https://www.checkout.com/) - AD, AE, AR, AT, AU, BE, BG, BH, BR, CH, CL, CN, CO, CY, CZ, DE, DK, EE, EG, ES, FI, FR, GB, GR, HK, HR, HU, IE, IS, IT, JO, JP, KW, LI, LT, LU, LV, MC, MT, MX, MY, NL, NO, NZ, OM, PE, PL, PT, QA, RO, SA, SE, SG, SI, SK, SM, TR, US
* [Clearhaus](https://www.clearhaus.com) - AD, AT, BE, BG, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GB, GL, GR, HR, HU, IE, IS, IT, LI, LT, LU, LV, MT, NL, NO, PL, PT, RO, SE, SI, SK
* [Commercegate](http://www.commercegate.com/) - AD, AT, AX, BE, BG, CH, CY, CZ, DE, DK, ES, FI, FR, GB, GG, GI, GR, HR, HU, IE, IM, IS, IT, JE, LI, LT, LU, LV, MC, MT, NL, NO, PL, PT, RO, SE, SI, SK, VA
* [Conekta](https://conekta.io) - MX
* [CyberSource](http://www.cybersource.com) - US, BR, CA, CN, DK, FI, FR, DE, JP, MX, NO, SE, GB, SG
* [DIBS](http://www.dibspayment.com/) - US, FI, NO, SE, GB
* [DataCash](http://www.datacash.com/) - GB
* [Efsnet](http://www.concordefsnet.com/) - US
* [Elavon MyVirtualMerchant](http://www.elavon.com/) - US, CA
* [ePay](http://epay.dk/) - DK, SE, NO
* [EVO Canada](http://www.evocanada.com/) - CA
* [eWAY](http://www.eway.com.au/) - AU, NZ, GB
* [eWAY Rapid](http://www.eway.com.au/) - AU, NZ, GB, SG
* [E-xact](http://www.e-xact.com) - CA, US
* [Ezic](http://www.ezic.com/) - AU, CA, CN, FR, DE, GI, IL, MT, MU, MX, NL, NZ, PA, PH, RU, SG, KR, ES, KN, GB
* [Fat Zebra](https://www.fatzebra.com.au/) - AU
* [Federated Canada](http://www.federatedcanada.com/) - CA
* [Finansbank WebPOS](https://www.fbwebpos.com/) - US, TR
* [Flo2Cash](http://www.flo2cash.co.nz/) - NZ
* [1stPayGateway.Net](http://1stpaygateway.net/) - US
* [FirstData Global Gateway e4](http://www.firstdata.com) - CA, US
* [FirstGiving](http://www.firstgiving.com/) - US
* [Garanti Sanal POS](https://sanalposweb.garanti.com.tr) - US, TR
* [Global Transport](https://www.globalpaymentsinc.com) - CA, PR, US
* [HDFC](http://www.hdfcbank.com/sme/sme-details/merchant-services/guzh6m0i) - IN
* [Heartland Payment Systems](http://developer.heartlandpaymentsystems.com/SecureSubmit/) - US
* [iATS Payments](http://home.iatspayments.com/) - AU, BR, CA, CH, DE, DK, ES, FI, FR, GR, HK, IE, IT, NL, NO, PT, SE, SG, TR, UK, US
* [Inspire Commerce](http://www.inspiregateway.com) - US
* [InstaPay](http://www.instapayllc.com) - US
* [IPP](http://www.ippayments.com.au/) - AU
* [Iridium](http://www.iridiumcorp.co.uk/) - GB, ES
* [iTransact](http://www.itransact.com/) - US
* [JetPay](http://www.jetpay.com/) - US
* [Komoju](http://www.komoju.com/) - JP
* [LinkPoint](http://www.linkpoint.com/) - US
* [Litle & Co.](http://www.litle.com/) - US
* [maxiPago!](http://www.maxipago.com/) - BR
* [Merchant e-Solutions](http://www.merchante-solutions.com/) - US
* [Merchant One Gateway](http://merchantone.com/) - US
* [MerchantWARE](http://merchantwarehouse.com/merchantware) - US
* [MerchantWarrior](http://www.merchantwarrior.com/) - AU
* [Mercury](http://www.mercurypay.com) - US, CA
* [Metrics Global](http://www.metricsglobal.com) - US
* [MasterCard Internet Gateway Service (MiGS)](http://mastercard.com/mastercardsps) - AU, AE, BD, BN, EG, HK, ID, IN, JO, KW, LB, LK, MU, MV, MY, NZ, OM, PH, QA, SA, SG, TT, VN
* [Modern Payments](http://www.modpay.com) - US
* [MONEI](http://www.monei.net/) - AD, AT, BE, BG, CA, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GB, GI, GR, HU, IE, IL, IS, IT, LI, LT, LU, LV, MT, NL, NO, PL, PT, RO, SE, SI, SK, TR, US, VA
* [Moneris](http://www.moneris.com/) - CA
* [MoneyMovers](http://mmoa.us/) - US
* [NAB Transact](http://transact.nab.com.au) - AU
* [NELiX TransaX](https://www.nelixtransax.com/) - US
* [NetRegistry](http://www.netregistry.com.au) - AU
* [BBS Netaxept](http://www.betalingsterminal.no/Netthandel-forside/) - NO, DK, SE, FI
* [NETbilling](http://www.netbilling.com) - US
* [NETPAY Gateway](http://www.netpay.com.mx) - MX
* [NMI](http://nmi.com/) - US
* [Ogone](http://www.ogone.com/) - BE, DE, FR, NL, AT, CH
* [Omise](https://www.omise.co/) - TH, JP
* [Openpay](Openpay) - MX
* [Optimal Payments](http://www.optimalpayments.com/) - CA, US, GB
* [Orbital Paymentech](http://chasepaymentech.com/) - US, CA
* [Pagar.me](https://pagar.me/) - BR
* [PagoFacil](http://www.pagofacil.net/) - MX
* [PayConex](http://www.bluefincommerce.com/) - US, CA
* [PayGate PayXML](http://paygate.co.za/) - US, ZA
* [PayHub](http://www.payhub.com/) - US
* [PayJunction](http://www.payjunction.com/) - US
* [PaySecure](http://www.commsecure.com.au/paysecure.shtml) - AU
* [Paybox Direct](http://www.paybox.com/) - FR
* [Payeezy](https://developer.payeezy.com/) - CA, US
* [Payex](http://payex.com/) - DK, FI, NO, SE
* [Windcave (formerly PaymentExpress)](https://www.windcave.com/) - AU, CA, DE, ES, FR, GB, HK, IE, MY, NL, NZ, SG, US, ZA
* [PAYMILL](https://paymill.com) - AD, AT, BE, BG, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GB, GI, GR, HU, IE, IL, IS, IT, LI, LT, LU, LV, MT, NL, NO, PL, PT, RO, SE, SI, SK, TR, VA
* [PayPal Express Checkout](https://www.paypal.com/webapps/mpp/express-checkout) - US, CA, SG, AU
* [PayPal Express Checkout (UK)](https://www.paypal.com/uk/webapps/mpp/express-checkout) - GB
* [PayPal Payflow Pro](https://www.paypal.com/webapps/mpp/payflow-payment-gateway) - US, CA, SG, AU
* [PayPal Payments Pro (US)](https://www.paypal.com/us/webapps/mpp/paypal-payments-pro) - US
* [PayPal Payments Pro (UK)](https://www.paypal.com/uk/webapps/mpp/pro) - GB
* [PayPal Website Payments Pro (CA)](https://www.paypal.com/cgi-bin/webscr?cmd=_wp-pro-overview-outside) - CA
* [PayPal Express Checkout for Digital Goods](https://www.x.com/community/ppx/xspaces/digital_goods) - AU, CA, CN, FI, GB, ID, IN, IT, MY, NO, NZ, PH, PL, SE, SG, TH, VN
* [Payscout](http://www.payscout.com/) - US
* [Paystation](http://paystation.co.nz) - NZ
* [Pay Way](http://www.payway.com.au) - AU
* [PayU India](https://www.payu.in/) - IN
* [Pin Payments](http://www.pinpayments.com/) - AU
* [Plug'n Pay](http://www.plugnpay.com/) - US
* [Psigate](http://www.psigate.com/) - CA
* [PSL Payment Solutions](http://www.paymentsolutionsltd.com/) - GB
* [QuickBooks Merchant Services](http://payments.intuit.com/) - US
* [QuickBooks Payments](http://payments.intuit.com/) - US
* [Quantum Gateway](http://www.quantumgateway.com) - US
* [QuickPay](http://quickpay.net/) - AT, BE, BG, CY, CZ, DE, DK, EE, ES, FI, FR, GB, GR, HR, HU, IE, IS, IT, LI, LT, LU, LV, MT, NL, NO, PL, PT, RO, SE SI, SK
* [Qvalent](https://www.qvalent.com/) - AU
* [Raven](http://www.deepcovelabs.com/raven) - AI, AN, AT, AU, BE, BG, BS, BZ, CA, CH, CR, CY, CZ, DE, DK, DM, DO, EE, EL, ES, FI, FR, GB, GG, GI, HK, HR, HU, IE, IL, IM, IN, IT, JE, KN, LI, LT, LU, LV, MH, MT, MY, NL, NO, NZ, PA, PE, PH, PL, PT, RO, RS, SC, SE, SG, SI, SK, UK, US, VG, ZA
* [Realex](http://www.realexpayments.com/) - IE, GB, FR, BE, NL, LU, IT
* [Redsys](http://www.redsys.es/) - ES
* [S5](http://www.s5.dk/) - DK
* [SagePay](http://www.sagepay.com) - GB, IE
* [Sage Payment Solutions](http://www.sagepayments.com) - US, CA
* [Sallie Mae](http://www.salliemae.com/) - US
* [SecureNet](http://www.securenet.com/) - US
* [SecurePay](http://www.securepay.com/) - US, CA, GB, AU
* [SecurePayTech](http://www.securepaytech.com/) - NZ
* [SecurionPay](https://securionpay.com/) - AD, BE, BG, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GI, GL, GR, GS, GT, HR, HU, IE, IS, IT, LI, LR, LT, LU, LV, MC, MT, MU, MV, MW, NL, NO, PL, RO, SE, SI
* [SkipJack](http://www.skipjack.com/) - US, CA
* [SoEasyPay](http://www.soeasypay.com/) - US, CA, AT, BE, BG, HR, CY, CZ, DK, EE, FI, FR, DE, GR, HU, IE, IT, LV, LT, LU, MT, NL, PL, PT, RO, SK, SI, ES, SE, GB, IS, NO, CH
* [Spreedly](https://spreedly.com) - AD, AE, AT, AU, BD, BE, BG, BN, CA, CH, CY, CZ, DE, DK, EE, EG, ES, FI, FR, GB, GI, GR, HK, HU, ID, IE, IL, IM, IN, IS, IT, JO, KW, LB, LI, LK, LT, LU, LV, MC, MT, MU, MV, MX, MY, NL, NO, NZ, OM, PH, PL, PT, QA, RO, SA, SE, SG, SI, SK, SM, TR, TT, UM, US, VA, VN, ZA
* [Stripe](https://stripe.com/) - AT, AU, BE, CA, CH, DE, DK, ES, FI, FR, GB, IE, IT, LU, NL, NO, SE, SG, US
* [Swipe](https://www.swipehq.com/checkout) - CA, NZ
* [TNS](http://www.tnsi.com/) - AR, AU, BR, FR, DE, HK, MX, NZ, SG, GB, US
* [Transact Pro](https://www.transactpro.lv/business/online-payments-acceptance) - US
* [TransFirst](http://www.transfirst.com/) - US
* [Transnational](http://www.tnbci.com/) - US
* [Trexle](https://trexle.com) - AD, AE, AT, AU, BD, BE, BG, BN, CA, CH, CY, CZ, DE, DK, EE, EG, ES, FI, FR, GB, GI, GR, HK, HU, ID, IE, IL, IM, IN, IS, IT, JO, KW, LB, LI, LK, LT, LU, LV, MC, MT, MU, MV, MX, MY, NL, NO, NZ, OM, PH, PL, PT, QA, RO, SA, SE, SG, SI, SK, SM, TR, TT, UM, US, VA, VN, ZA
* [TrustCommerce](http://www.trustcommerce.com/) - US
* [USA ePay](http://www.usaepay.com/) - US
* [Vanco Payment Solutions](http://vancopayments.com/) - US
* [Verifi](http://www.verifi.com/) - US
* [ViaKLIX](http://viaklix.com) - US
* [WebPay](https://webpay.jp/) - JP
* [WePay](https://www.wepay.com/) - US
* [Wirecard](http://www.wirecard.com) - AD, CY, GI, IM, MT, RO, CH, AT, DK, GR, IT, MC, SM, TR, BE, EE, HU, LV, NL, SK, GB, BG, FI, IS, LI, NO, SI, VA, FR, IL, LT, PL, ES, CZ, DE, IE, LU, PT, SE
* [Worldpay Global](http://www.worldpay.com/) - HK, GB, AU, AD, BE, CH, CY, CZ, DE, DK, ES, FI, FR, GI, GR, HU, IE, IL, IT, LI, LU, MC, MT, NL, NO, NZ, PL, PT, SE, SG, SI, SM, TR, UM, VA
* [Worldpay Online](https://online.worldpay.com/) - HK, US, GB, AU, AD, BE, CH, CY, CZ, DE, DK, ES, FI, FR, GI, GR, HU, IE, IL, IT, LI, LU, MC, MT, NL, NO, NZ, PL, PT, SE, SG, SI, SM, TR, UM, VA
* [Worldpay US](http://www.worldpay.com/us) - US

## API stability policy

Functionality or APIs that are deprecated will be marked as such. Deprecated functionality is removed on major version changes - for example, deprecations from 2.x are removed in 3.x.

## Ruby and Rails compatibility policies

Because Active Merchant is a payment library, it needs to take security seriously. For this reason, Active Merchant guarantees compatibility only with actively supported versions of Ruby and Rails. At the time of this writing, that means that Ruby 2.5+ and Rails 5.0+ are supported.
