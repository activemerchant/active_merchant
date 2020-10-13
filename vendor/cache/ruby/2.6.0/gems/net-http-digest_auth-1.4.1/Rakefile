# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :git
Hoe.plugin :minitest
Hoe.plugin :travis

Hoe.spec 'net-http-digest_auth' do
  developer 'Eric Hodel', 'drbrain@segment7.net'

  rdoc_locations <<
    'docs.seattlerb.org:/data/www/docs.seattlerb.org/net-http-digest_auth/'
  rdoc_locations <<
    'rubyforge.org:/var/www/gforge-projects/seattlerb/net-http-digest_auth/'

  license 'MIT'

  dependency 'minitest', '~> 5.0', :development

  self.spec_extras[:required_ruby_version] = '>= 1.8.7'
end

# vim: syntax=Ruby
