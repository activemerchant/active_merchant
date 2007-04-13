#
# = test-uuid.rb - UUID generator test cases
#
# Author:: Assaf Arkin  assaf@labnotes.org
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/Ruby/UuidGenerator
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: MIT and/or Creative Commons Attribution-ShareAlike
#
#--
#++


require 'test/unit'
require 'uuid'

class TestUUID < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_format
    10.times do
      uuid = UUID.new :compact
      assert uuid =~ /^[0-9a-fA-F]{32}$/, "UUID does not conform to :compact format"
      uuid = UUID.new :default
      assert uuid =~ /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/, "UUID does not conform to :default format"
      uuid = UUID.new :urn
      assert uuid =~ /^urn:uuid:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/i, "UUID does not conform to :urn format"
    end
  end

  def test_monotonic
    count = 100000
    seen = {}
    count.times do |i|
      uuid = UUID.new
      assert !seen.has_key?(uuid), "UUID repeated"
      seen[uuid] = true
      print '.' if (i % 10000) == 0
      STDOUT.flush
    end
  end

end

