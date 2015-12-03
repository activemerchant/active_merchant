# Contributing guidelines

We gladly accept new gateways or bugfixes to this library. Please read the guidelines for reporting issues and submitting pull requests below.

### Reporting issues

- Please make clear in the subject what gateway the issue is about.
- Include the version of ActiveMerchant, Ruby, ActiveSupport, and Nokogiri you are using.

### Pull request guidelines

1. [Fork it](http://github.com/activemerchant/active_merchant/fork) and clone your new repo
2. Create a branch (`git checkout -b my_awesome_feature`)
3. Commit your changes (`git add my/awesome/file.rb; git commit -m "Added my awesome feature"`)
4. Push your changes to your fork (`git push origin my_awesome_feature`)
5. Open a [Pull Request](https://github.com/activemerchant/active_merchant/pulls)

Please see the [ActiveMerchant Guide to Contributing](https://github.com/activemerchant/active_merchant/wiki/contributing) for information on adding a new gateway to ActiveMerchant.

The most important guidelines:

- All new integrations must have unit tests and functional remote tests.
- Remote tests for a gateway should cover all supported transaction methods (auth, capture, refund, void) and validate critical response formats such as charge amounts.
- Your code should support all the Ruby versions and ActiveSupport versions we have enabled on Travis CI.
- No new gem dependencies will be accepted.
- **XML**: use Nokogiri for generating and parsing XML.
- **JSON**: use `JSON` in the standard library to parse and generate JSON.
- **HTTP**: use `ActiveMerchant::PostsData` to do HTTP requests.
- Do not update the CHANGELOG, or the `ActiveMerchant::VERSION` constant.

### Placement within Shopify

The addition of your gateway to active_merchant does not guarantee placement within Shopify. In order to have your gateway considered, please send an email to payment-integrations@shopify.com with **Active_Merchant Integration** in the subject. Be sure to include:

1. Name, URL & description of the payment provider you wish to integrate
2. Markets served by this integration
3. List of major supported payment methods
4. Your most recent Certificate of PCI Compliance

### Releasing

1. Check the [semantic versioning page](http://semver.org) for info on how to version the new release.
2. Update the  `ActiveMerchant::VERSION` constant in **lib/active_merchant/version.rb**.
3. Add a `CHANGELOG` entry for the new release with the date
4. Tag the release commit on GitHub: `bundle exec rake tag_release`
5. Release the gem to rubygems using ShipIt
