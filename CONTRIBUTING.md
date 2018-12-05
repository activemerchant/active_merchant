# Contributing guidelines

We gladly accept bugfixes, but are not actively looking to add new gateways. Please follow the guidelines here to ensure your work is accepted.

## New Gateways

We're not taking on many new gateways at the moment. The team maintaining ActiveMerchant is small and with the limited resources available, we generally prefer not to support a gateway than to support a gateway poorly.

Please see the [ActiveMerchant Guide to Contributing a new Gateway](https://github.com/activemerchant/active_merchant/wiki/contributing) for information on creating a new gateway. You can place your gateway code in your application's `lib/active_merchant/billing` folder to use it.

We would like to work with the community to figure out how gateways can release and maintain their integrations outside of the the ActiveMerchant repository. Please join [the discussion](https://github.com/activemerchant/active_merchant/issues/2923) if you're interested or have ideas.

Gateway placement within Shopify is available by invitation only at this time.

## Issues & Bugfixes

### Reporting issues

When filing a new Issue:

- Please make clear in the subject what gateway the issue is about.
- Include the version of ActiveMerchant, Ruby, ActiveSupport, and Nokogiri you are using.

### Pull request guidelines

When submitting a pull request to resolve an issue:

1. [Fork it](http://github.com/activemerchant/active_merchant/fork) and clone your new repo
2. Create a branch (`git checkout -b my_awesome_feature`)
3. Commit your changes (`git add my/awesome/file.rb; git commit -m "Added my awesome feature"`)
4. Push your changes to your fork (`git push origin my_awesome_feature`)
5. Open a [Pull Request](https://github.com/activemerchant/active_merchant/pulls)

## Version/Release Management

Contributors don't need to worry about versions, this is something Committers do at important milestones:

1. Check the [semantic versioning page](http://semver.org) for info on how to version the new release.
2. Update the  `ActiveMerchant::VERSION` constant in **lib/active_merchant/version.rb**.
3. Add a `CHANGELOG` entry for the new release with the date
4. Tag the release commit on GitHub: `bundle exec rake tag_release`
5. Release the gem to rubygems using ShipIt
