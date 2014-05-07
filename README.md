# Active Merchant
[![Build Status](https://travis-ci.org/Shopify/active_merchant.png?branch=master)](https://travis-ci.org/Shopify/active_merchant)
[![Code Climate](https://codeclimate.com/github/Shopify/active_merchant.png)](https://codeclimate.com/github/Shopify/active_merchant)

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

## Installation

### From Git

You can check out the latest source from git:

    git clone git://github.com/Shopify/active_merchant.git

### From RubyGems

Installation from RubyGems:

    gem install activemerchant

Or, if you're using Bundler, just add the following to your Gemfile:

    gem 'activemerchant'

## Usage

This simple example demonstrates how a purchase can be made using a person's
credit card details.

```ruby
require 'rubygems'
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
if credit_card.valid?
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
[API documentation](http://rubydoc.info/github/Shopify/active_merchant/master/file/README.md).

## Supported Direct Payment Gateways

The [ActiveMerchant Wiki](http://github.com/Shopify/active_merchant/wikis) contains a [table of features supported by each gateway](http://github.com/Shopify/active_merchant/wikis/gatewayfeaturematrix).

* [App55](https://www.app55.com/) - AU, BR, CA, CH, CL, CN, CO, CZ, DK, EU, GB, HK, HU, ID, IS, JP, KE, KR, MX, MY, NO, NZ, PH, PL, TH, TW, US, VN, ZA
* [Authorize.Net CIM](http://www.authorize.net/) - US
* [Authorize.Net](http://www.authorize.net/) - AD, AT, AU, BE, BG, CA, CH, CY, CZ, DE, DK, ES, FI, FR, GB, GB, GI, GR, HU, IE, IT, LI, LU, MC, MT, NL, NO, PL, PT, RO, SE, SI, SK, SM, TR, US, VA
* [Balanced](https://www.balancedpayments.com/) - US
* [Banwire](http://www.banwire.com/) - MX
* [Barclays ePDQ Extra Plus](http://www.barclaycard.co.uk/business/accepting-payments/epdq-ecomm/) - GB
* [Barclays ePDQ MPI](http://www.barclaycard.co.uk/business/accepting-payments/epdq-mpi/) - GB
* [Be2Bill](http://www.be2bill.com/) - FR
* [Beanstream.com](http://www.beanstream.com/) - CA, US
* [BluePay](http://www.bluepay.com/) - US
* [Braintree](http://www.braintreepaymentsolutions.com) - US, CA, AU, AD, AT, BE, BG, CY, CZ, DK, EE, FI, FR, GI, DE, GR, HU, IS, IM, IE, IT, LV, LI, LT, LU, MT, MC, NL, NO, PL, PT, RO, SM, SK, SI, ES, SE, CH, TR, GB
* [BridgePay](http://www.bridgepaynetwork.com/) - CA, US
* [CardSave](http://www.cardsave.net/) - GB
* [CardStream](http://www.cardstream.com/) - GB
* [Cecabank](http://www.ceca.es/es/) - ES
* [CertoDirect](http://www.certodirect.com/) - BE, BG, CZ, DK, DE, EE, IE, EL, ES, FR, IT, CY, LV, LT, LU, HU, MT, NL, AT, PL, PT, RO, SI, SK, FI, SE, GB
* [Conekta](https://conekta.io) - MX
* [CyberSource](http://www.cybersource.com) - US, BR, CA, CN, DK, FI, FR, DE, JP, MX, NO, SE, GB, SG
* [DataCash](http://www.datacash.com/) - GB
* [Efsnet](http://www.concordefsnet.com/) - US
* [Elavon MyVirtualMerchant](http://www.elavon.com/) - US, CA
* [ePay](http://epay.dk/) - DK, SE, NO
* [EVO Canada](http://www.evocanada.com/) - CA
* [eWAY](http://www.eway.com.au/) - AU, NZ, GB
* [eWAY Rapid 3.0](http://www.eway.com.au/) - AU
* [E-xact](http://www.e-xact.com) - CA, US
* [Fat Zebra](https://www.fatzebra.com.au/) - AU
* [Federated Canada](http://www.federatedcanada.com/) - CA
* [Finansbank WebPOS](https://www.fbwebpos.com/) - US, TR
* [First Pay](http://www.first-pay.com) - US
* [FirstData Global Gateway e4](http://www.firstdata.com) - CA, US
* [FirstGiving](http://www.firstgiving.com/) - US
* [Garanti Sanal POS](https://sanalposweb.garanti.com.tr) - US, TR
* [HDFC](http://www.hdfcbank.com/sme/sme-details/merchant-services/guzh6m0i) - IN
* [iATS Payments](http://home.iatspayments.com/) - AU, CA, CH, DE, DK, ES, FI, FR, GR, HK, IE, IT, JP, NL, NO, NZ, PT, SE, SG, TR, UK, US
* [Inspire Commerce](http://www.inspiregateway.com) - US
* [InstaPay](http://www.instapayllc.com) - US
* [Iridium](http://www.iridiumcorp.co.uk/) - GB, ES
* [iTransact](http://www.itransact.com/) - US
* [JetPay](http://www.jetpay.com/) - US
* [LinkPoint](http://www.linkpoint.com/) - US
* [Litle & Co.](http://www.litle.com/) - US
* [maxiPago!](http://www.maxipago.com/) - BR
* [Merchant e-Solutions](http://www.merchante-solutions.com/) - US
* [Merchant One Gateway](http://merchantone.com/) - US
* [MerchantWARE](http://merchantwarehouse.com/merchantware) - US
* [MerchantWarrior](http://www.merchantwarrior.com/) - AU
* [Mercury](http://www.mercurypay.com) - US
* [Metrics Global](http://www.metricsglobal.com) - US
* [MasterCard Internet Gateway Service (MiGS)](http://mastercard.com/mastercardsps) - AU, AE, BD, BN, EG, HK, ID, IN, JO, KW, LB, LK, MU, MV, MY, NZ, OM, PH, QA, SA, SG, TT, VN
* [Modern Payments](http://www.modpay.com) - US
* [Moneris](http://www.moneris.com/) - CA
* [Moneris (US)](http://www.monerisusa.com/) - US
* [MoneyMovers](http://mmoa.us/) - US
* [NAB Transact](http://transact.nab.com.au) - AU
* [NetRegistry](http://www.netregistry.com.au) - AU
* [BBS Netaxept](http://www.betalingsterminal.no/Netthandel-forside/) - NO, DK, SE, FI
* [NETbilling](http://www.netbilling.com) - US
* [NETPAY Gateway](http://www.netpay.com.mx) - MX
* [NMI](http://nmi.com/) - US
* [Ogone](http://www.ogone.com/) - BE, DE, FR, NL, AT, CH
* [Openpay](Openpay) - MX
* [Optimal Payments](http://www.optimalpayments.com/) - CA, US, GB
* [Orbital Paymentech](http://chasepaymentech.com/) - US, CA
* [PagoFacil](http://www.pagofacil.net/) - MX
* [PayGate PayXML](http://paygate.co.za/) - US, ZA
* [PayJunction](http://www.payjunction.com/) - US
* [PaySecure](http://www.commsecure.com.au/paysecure.shtml) - AU
* [Paybox Direct](http://www.paybox.com/) - FR
* [Payex](http://payex.com/) - DK, FI, NO, SE
* [PaymentExpress](http://www.paymentexpress.com/) - AU, CA, DE, ES, FR, GB, HK, IE, MY, NL, NZ, SG, US, ZA
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
* [Pin](http://www.pin.net.au/) - AU
* [Plug'n Pay](http://www.plugnpay.com/) - US
* [Psigate](http://www.psigate.com/) - CA
* [PSL Payment Solutions](http://www.paymentsolutionsltd.com/) - GB
* [QuickBooks Merchant Services](http://payments.intuit.com/) - US
* [Quantum Gateway](http://www.quantumgateway.com) - US
* [Quickpay](http://quickpay.dk/) - DK, SE
* [Raven PacNet](http://www.pacnetservices.com/) - US
* [Realex](http://www.realexpayments.com/) - IE, GB, FR, BE, NL, LU, IT
* [Redsys](http://www.redsys.es/) - ES
* [SagePay](http://www.sagepay.com) - GB, IE
* [Sage Payment Solutions](http://www.sagepayments.com) - US, CA
* [Sallie Mae](http://www.salliemae.com/) - US
* [Samurai](https://samurai.feefighters.com) - US
* [SecureNet](http://www.securenet.com/) - US
* [SecurePay](http://www.securepay.com/) - US, CA, GB, AU
* [SecurePayTech](http://www.securepaytech.com/) - NZ
* [SkipJack](http://www.skipjack.com/) - US, CA
* [SoEasyPay](http://www.soeasypay.com/) - US, CA, AT, BE, BG, HR, CY, CZ, DK, EE, FI, FR, DE, GR, HU, IE, IT, LV, LT, LU, MT, NL, PL, PT, RO, SK, SI, ES, SE, GB, IS, NO, CH
* [Spreedly](https://spreedly.com) - AD, AE, AT, AU, BD, BE, BG, BN, CA, CH, CY, CZ, DE, DK, EE, EG, ES, FI, FR, GB, GI, GR, HK, HU, ID, IE, IL, IM, IN, IS, IT, JO, KW, LB, LI, LK, LT, LU, LV, MC, MT, MU, MV, MX, MY, NL, NO, NZ, OM, PH, PL, PT, QA, RO, SA, SE, SG, SI, SK, SM, TR, TT, UM, US, VA, VN, ZA
* [Stripe](https://stripe.com/) - US, CA, GB, AU, IE, FR, NL, BE, DE, ES
* [Swipe](https://www.swipehq.com/checkout) - CA, NZ
* [TransFirst](http://www.transfirst.com/) - US
* [NELiX TransaX](https://www.nelixtransax.com/) - US
* [Transnational](http://www.tnbci.com/) - US
* [TrustCommerce](http://www.trustcommerce.com/) - US
* [USA ePay](http://www.usaepay.com/) - US
* [Verifi](http://www.verifi.com/) - US
* [ViaKLIX](http://viaklix.com) - US
* [Vindicia](http://www.vindicia.com/) - US, CA, GB, AU, MX, BR, DE, KR, CN, HK
* [WebPay](https://webpay.jp/) - JP
* [WePay](https://www.wepay.com/) - US
* [Wirecard](http://www.wirecard.com) - AD, CY, GI, IM, MT, RO, CH, AT, DK, GR, IT, MC, SM, TR, BE, EE, HU, LV, NL, SK, GB, BG, FI, IS, LI, NO, SI, VA, FR, IL, LT, PL, ES, CZ, DE, IE, LU, PT, SE
* [WorldPay](http://www.worldpay.com/) - HK, US, GB, AU, AD, BE, CH, CY, CZ, DE, DK, ES, FI, FR, GI, GR, HU, IE, IL, IT, LI, LU, MC, MT, NL, NO, NZ, PL, PT, SE, SG, SI, SM, TR, UM, VA

## Supported Offsite Payment Gateways

* [2 Checkout](http://www.2checkout.com)
* [A1Agregator](http://a1agregator.ru/) - RU
* [Authorize.Net SIM](http://developer.authorize.net/api/sim/) - US
* [Banca Sella GestPay](https://www.sella.it/banca/ecommerce/gestpay/gestpay.jsp)
* [Chronopay](http://www.chronopay.com)
* [DirecPay](http://www.timesofmoney.com/direcpay/jsp/home.jsp)
* [Direct-eBanking / sofortueberweisung.de by Payment-Networks AG](https://www.payment-network.com/deb_com_en/merchantarea/home) - DE, AT, CH, BE, UK, NL
* [Dotpay](http://dotpay.pl)
* [Doku](http://doku.com)
* [Dwolla](https://www.dwolla.com/default.aspx)
* [ePay](http://www.epay.dk/epay-payment-solutions/)
* [First Data](https://firstdata.zendesk.com/entries/407522-first-data-global-gateway-e4sm-payment-pages-integration-manual)
* [HiTRUST](http://www.hitrust.com.hk/)
* [Moneybookers](http://www.moneybookers.com)
* [Nochex](http://www.nochex.com)
* [Paxum](https://www.paxum.com/)
* [PayPal Website Payments Standard](https://www.paypal.com/cgi-bin/webscr?cmd#_wp-standard-overview-outside)
* [Paysbuy](https://www.paysbuy.com/) - TH
* [Platron](https://www.platron.ru/) - RU
* [RBK Money](https://rbkmoney.ru/) - RU
* [Robokassa](http://robokassa.ru/) - RU
* [SagePay Form](http://www.sagepay.com/products_services/sage_pay_go/integration/form)
* [Suomen Maksuturva](https://www.maksuturva.fi/services/vendor_services/integration_guidelines.html)
* [Valitor](http://www.valitor.is/) - IS
* [Verkkomaksut](http://www.verkkomaksut.fi) - FI
* [WebMoney](http://www.webmoney.ru) - RU
* [WebPay](http://webpay.by/)
* [WorldPay](http://www.worldpay.com)

## Contributing

The source code is hosted at [GitHub](http://github.com/Shopify/active_merchant), and can be fetched using:

    git clone git://github.com/Shopify/active_merchant.git

Please see the [ActiveMerchant Guide to Contributing](http://github.com/Shopify/active_merchant/wikis/contributing) for
information on adding a new gateway to ActiveMerchant.

Please don't touch the CHANGELOG in your pull requests, we'll add the appropriate CHANGELOG entries
at release time.
