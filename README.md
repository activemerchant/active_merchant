Forked from:
# Active Merchant
[![Build Status](https://travis-ci.org/activemerchant/active_merchant.png?branch=master)](https://travis-ci.org/activemerchant/active_merchant)
[![Code Climate](https://codeclimate.com/github/activemerchant/active_merchant.png)](https://codeclimate.com/github/activemerchant/active_merchant)

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

## Modifications on this branch
### New feature: 
Integrated the [IPP(Bambora)](https://www.bambora.com/) gateway into [Beanstream](https://www.beanstream.com/) gateway, use BeanstreamGateway as an unified entrance for both the gateways.
### New parameter:
Add the <em>:region</em> to the <strong>options</strong> parameter:
1. For US & CA, <em>:region</em> is 0;
1. For AU, <em>:region</em> is 1.
### New logic:
1. Process payment requests from US & CA by Beanstream service (default);
2. Process payment requests from AU by IPP(Bambora) service.
### Others:
Remove IPP gateway files.
### Tests:

#### Unit
<pre>
<code>
bundle exec rake test:units TEST=test/unit/gateways/beanstream_test.rb

bundle exec rake test:units TEST=test/unit/gateways/beanstream_ipp_test.rb
</code>
</pre>
#### Remote
<pre>
<code>
bundle exec rake test:remote TEST=test/remote/gateways/remote_beanstream_test.rb

bundle exec rake test:remote TEST=test/remote/gateways/remote_beanstream_ipp_test.rb
</code>
</pre>


