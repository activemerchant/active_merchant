# Active Merchant
[![Build Status](https://secure.travis-ci.org/Shopify/active_merchant.png)](http://travis-ci.org/Shopify/active_merchant)
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/Shopify/active_merchant)

Active Merchant is an extraction from the e-commerce system [Shopify](http://www.shopify.com).
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

For more in-depth documentation and tutorials, see [GettingStarted.md](GettingStarted.md) and the
[API documentation](http://rubydoc.info/github/Shopify/active_merchant/master/file/README.md).

## Supported Direct Payment Gateways

The [ActiveMerchant Wiki](http://github.com/Shopify/active_merchant/wikis) contains a [table of features supported by each gateway](http://github.com/Shopify/active_merchant/wikis/gatewayfeaturematrix).

* [Authorize.Net](http://www.authorize.net/) - US
* [Authorize.Net CIM](http://www.authorize.net/) - US
* [Balanced](https://www.balancedpayments.com/) - US
* [Banwire](https://www.banwire.com/) - MX
* [Barclays ePDQ MPI](http://www.barclaycard.co.uk/business/accepting-payments/epdq-mpi/) - UK
* [Barclays ePDQ Extra Plus](http://www.barclaycard.co.uk/business/accepting-payments/epdq-ecomm/) - UK
* [Beanstream.com](http://www.beanstream.com/) - CA
* [BluePay](http://www.bluepay.com/) - US
* [Braintree](http://www.braintreepaymentsolutions.com) - US
* [CardStream](http://www.cardstream.com/) - UK
* [CertoDirect](http://www.certodirect.com/) - BE, BG, CZ, DK, DE, EE, IE, EL, ES, FR, IT, CY, LV, LT, LU, HU, MT, NL, AT, PL, PT, RO, SI, SK, FI, SE, UK
* [CyberSource](http://www.cybersource.com) - US
* [DataCash](http://www.datacash.com/) - UK
* [Efsnet](http://www.concordefsnet.com/) - US
* [Elavon MyVirtualMerchant](http://www.elavon.com) - US, CA
* [ePay](http://www.epay.dk/) - DK, SE, NO
* [EVO Canada](http://www.evocanada.com/) - CA
* [eWAY](http://www.eway.com.au/) - AU
* [eWay Rapid 3.0](http://www.eway.com.au/) - AU
* [E-xact](http://www.e-xact.com) - CA, US
* [Fat Zebra](https://www.fatzebra.com.au) - AU
* [Federated Canada](http://www.federatedcanada.com/) - CA
* [Finansbank WebPOS](https://www.fbwebpos.com/) - US, TR
* [FirstData Global Gateway e4](http://www.firstdata.com) - CA, US
* [FirstPay](http://www.first-pay.com) - US
* [Garanti Sanal POS](https://ccpos.garanti.com.tr/ccRaporlar/garanti/ccReports) - US, TR
* [HDFC](http://www.hdfcbank.com/sme/sme-details/merchant-services/guzh6m0i) - IN
* [Inspire](http://www.inspiregateway.com) - US
* [InstaPay](http://www.instapayllc.com) - US
* [Iridium](http://www.iridiumcorp.co.uk/) - UK, ES
* [iTransact](http://www.itransact.com/) - US
* [JetPay](http://www.jetpay.com) - US
* [LinkPoint](http://www.linkpoint.com/) - US
* [Litle](http://www.litle.com/) - US
* [Merchant e-Solutions](http://merchante-solutions.com/) - US
* [MerchantWare](http://merchantwarehouse.com/merchantware) - US
* [Merchant Warrior] (http://merchantwarrior.com) - AU
* [Mercury](http://www.mercurypay.com) - US
* [MasterCard Internet Gateway Service (MiGS)](http://mastercard.com/mastercardsps) - AU, AE, BD, BN, EG, HK, ID, IN, JO, KW, LB, LK, MU, MV, MY, NZ, OM, PH, QA, SA, SG, TT, VN
* [Modern Payments](http://www.modpay.com) - US
* [Moneris](http://www.moneris.com/) - CA
* [Moneris US](http://www.monerisusa.com/) - US
* [NABTransact](http://www.nab.com.au/nabtransact/) - AU
* [NELiX TransaX Gateway](http://www.nelixtransax.com) - US
* [Netaxept](http://www.betalingsterminal.no/Netthandel-forside) - NO, DK, SE, FI
* [NETbilling](http://www.netbilling.com) - US
* [NetPay](http://www.netpay.com.mx) - MX
* [NetRegistry](http://www.netregistry.com.au) - AU
* [NMI](http://nmi.com/) - US
* [Ogone DirectLink](http://www.ogone.com) - BE, DE, FR, NL, AT, CH
* [Optimal Payments](http://www.optimalpayments.com/) - CA, US, UK
* [Orbital Paymentech](http://chasepaymentech.com/) - CA, US, UK, GB
* [PayBox Direct](http://www.paybox.com) - FR
* [PayFast](https://www.payfast.co.za/) - ZA
* [PayGate PayXML](http://paygate.co.za/) - US, ZA
* [PayJunction](http://www.payjunction.com/) - US
* [PaymentExpress](http://www.paymentexpress.com/) - AU, MY, NZ, SG, ZA, UK, US
* [PAYMILL](https://www.paymill.com) - AD, AT, BE, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GB, GR, HU, IE, IL, IS, IT, LI, LT, LU, LV, MT, NL, NO, PL, PT, SE, SI, SK, TR, VA
* [PayPal Express Checkout](https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside) - US, CA, SG, AU
* [PayPal Payflow Pro](https://www.paypal.com/cgi-bin/webscr?cmd=_payflow-pro-overview-outside) - US, CA, SG, AU
* [PayPal Website Payments Pro (UK)](https://www.paypal.com/uk/cgi-bin/webscr?cmd=_wp-pro-overview-outside) - UK
* [PayPal Website Payments Pro (CA)](https://www.paypal.com/cgi-bin/webscr?cmd=_wp-pro-overview-outside) - CA
* [PayPal Express Checkout](https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside) - US
* [PayPal Website Payments Pro (US)](https://www.paypal.com/cgi-bin/webscr?cmd=_wp-pro-overview-outside) - US
* [PaySecure](http://www.commsecure.com.au/paysecure.shtml) - AU
* [PayWay](https://www.payway.com.au) - AU
* [Pin](http://www.pin.net.au/) - AU
* [Plug'n Pay](http://www.plugnpay.com/) - US
* [Psigate](http://www.psigate.com/) - CA
* [PSL Payment Solutions](http://www.paymentsolutionsltd.com/) - UK
* [Quantum](http://www.quantumgateway.com) - US
* [QuickBooks Merchant Services](http://payments.intuit.com/) - US
* [Quickpay](http://quickpay.dk/) - DK, SE
* [Rabobank Nederland](http://www.rabobank.nl/) - NL
* [Realex](http://www.realexpayments.com/) - IE, UK
* [Redsys](http://www.redsys.es) - ES
* [SagePay](http://www.sagepay.com) - UK
* [Sage Payment Solutions](http://www.sagepayments.com) - US, CA
* [Sallie Mae](http://www.salliemae.com) - US
* [SecureNet](http://www.securenet.com) - US
* [SecurePay](http://securepay.com.au) - AU
* [SecurePay](http://www.securepay.com/) - US
* [SecurePayTech](http://www.securepaytech.com/) - NZ
* [SkipJack](http://www.skipjack.com/) - US, CA
* [Spreedly Core](https://spreedlycore.com/) - AD, AE, AT, AU, BD, BE, BG, BN, CA, CH, CY, CZ, DE, DK, EE, EG, ES, FI, FR, GB, GI, GR, HK, HU, ID, IE, IL, IM, IN, IS, IT, JO, KW, LB, LI, LK, LT, LU, LV, MC, MT, MU, MV, MX, MY, NL, NO, NZ, OM, PH, PL, PT, QA, RO, SA, SE, SG, SI, SK, SM, TR, TT, UM, US, VA, VN, ZA
* [Stripe](https://stripe.com/) - US, CA, GB
* [TransFirst](http://www.transfirst.com/) - US
* [Transnational](http://www.tnbci.com/) - US
* [TrustCommerce](http://www.trustcommerce.com/) - US
* [USA ePay](http://www.usaepay.com/) - US
* [Verifi](http://www.verifi.com/) - US
* [ViaKLIX](http://viaklix.com) - US
* [Vindica](http://www.vindicia.com/) - US, CA, UK, AU, MX, BR, DE, KR, CN, HK
* [WebPay](https://webpay.jp/) - JP
* [Wirecard](http://www.wirecard.com) - DE
* [WorldPay](http://www.worldpay.com) - AU, HK, UK, US

## Supported Offsite Payment Gateways

* [2 Checkout](http://www.2checkout.com)
* [A1Agregator](http://a1agregator.ru/) - RU
* [Authorize.Net SIM](http://developer.authorize.net/api/sim/) - US
* [Banca Sella GestPay](https://www.sella.it/banca/ecommerce/gestpay/gestpay.jsp)
* [Chronopay](http://www.chronopay.com)
* [DirecPay](http://www.timesofmoney.com/direcpay/jsp/home.jsp)
* [Direct-eBanking / sofortueberweisung.de by Payment-Networks AG](https://www.payment-network.com/deb_com_en/merchantarea/home) - DE, AT, CH, BE, UK, NL
* [Dotpay](http://dotpay.pl)
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
