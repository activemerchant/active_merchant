require 'mechanize/test_case'

class TestMechanizeCookieJar < Mechanize::TestCase

  def setup
    super

    @jar = Mechanize::CookieJar.new

    @jar.extend Minitest::Assertions

    def @jar.add(*args)
      capture_io { super }
    end

    def @jar.jar(*args)
      result = nil
      capture_io { result = super }
      result
    end

    def @jar.save_as(*args)
      result = nil
      capture_io { result = super }
      result
    end

    def @jar.clear!(*args)
      result = nil
      capture_io { result = super }
      result
    end
  end

  def cookie_values(options = {})
    {
      :name     => 'Foo',
      :value    => 'Bar',
      :path     => '/',
      :expires  => Time.now + (10 * 86400),
      :for_domain => true,
      :domain   => 'rubyforge.org'
   }.merge(options)
  end

  def test_two_cookies_same_domain_and_name_different_paths
    url = URI 'http://rubyforge.org/'

    cookie = Mechanize::Cookie.new(cookie_values)
    @jar.add(url, cookie)
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:path => '/onetwo')))

    assert_equal(1, @jar.cookies(url).length)
    assert_equal 2, @jar.cookies(URI('http://rubyforge.org/onetwo')).length
  end

  def test_domain_case
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length)

    @jar.add(url, Mechanize::Cookie.new(
        cookie_values(:domain => 'RuByForge.Org', :name   => 'aaron')))

    assert_equal(2, @jar.cookies(url).length)

    url2 = URI 'http://RuByFoRgE.oRg/'
    assert_equal(2, @jar.cookies(url2).length)
  end

  def test_host_only
    url = URI.parse('http://rubyforge.org/')

    @jar.add(url, Mechanize::Cookie.new(
        cookie_values(:domain => 'rubyforge.org', :for_domain => false)))

    assert_equal(1, @jar.cookies(url).length)

    assert_equal(1, @jar.cookies(URI('http://RubyForge.org/')).length)

    assert_equal(1, @jar.cookies(URI('https://RubyForge.org/')).length)

    assert_equal(0, @jar.cookies(URI('http://www.rubyforge.org/')).length)
  end

  def test_empty_value
    values = cookie_values(:value => "")
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length)

    @jar.add url, Mechanize::Cookie.new(values.merge(:domain => 'RuByForge.Org',
                                                     :name   => 'aaron'))

    assert_equal(2, @jar.cookies(url).length)

    url2 = URI 'http://RuByFoRgE.oRg/'
    assert_equal(2, @jar.cookies(url2).length)
  end

  def test_add_future_cookies
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length)

    # Add the same cookie, and we should still only have one
    @jar.add(url, Mechanize::Cookie.new(cookie_values))
    assert_equal(1, @jar.cookies(url).length)

    # Make sure we can get the cookie from different paths
    assert_equal(1, @jar.cookies(URI('http://rubyforge.org/login')).length)

    # Make sure we can't get the cookie from different domains
    assert_equal(0, @jar.cookies(URI('http://google.com/')).length)
  end

  def test_add_multiple_cookies
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length)

    # Add the same cookie, and we should still only have one
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:name => 'Baz')))
    assert_equal(2, @jar.cookies(url).length)

    # Make sure we can get the cookie from different paths
    assert_equal(2, @jar.cookies(URI('http://rubyforge.org/login')).length)

    # Make sure we can't get the cookie from different domains
    assert_equal(0, @jar.cookies(URI('http://google.com/')).length)
  end

  def test_add_rejects_cookies_that_do_not_contain_an_embedded_dot
    url = URI 'http://rubyforge.org/'

    tld_cookie = Mechanize::Cookie.new(cookie_values(:domain => '.org'))
    @jar.add(url, tld_cookie)
    # single dot domain is now treated as no domain
    # single_dot_cookie = Mechanize::Cookie.new(cookie_values(:domain => '.'))
    # @jar.add(url, single_dot_cookie)

    assert_equal(0, @jar.cookies(url).length)
  end

  def test_fall_back_rules_for_local_domains
    url = URI 'http://www.example.local'

    tld_cookie = Mechanize::Cookie.new(cookie_values(:domain => '.local'))
    @jar.add(url, tld_cookie)

    assert_equal(0, @jar.cookies(url).length)

    sld_cookie = Mechanize::Cookie.new(cookie_values(:domain => '.example.local'))
    @jar.add(url, sld_cookie)

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_add_makes_exception_for_localhost
    url = URI 'http://localhost'

    tld_cookie = Mechanize::Cookie.new(cookie_values(:domain => 'localhost'))
    @jar.add(url, tld_cookie)

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_add_cookie_for_the_parent_domain
    url = URI 'http://x.foo.com'

    cookie = Mechanize::Cookie.new(cookie_values(:domain => '.foo.com'))
    @jar.add(url, cookie)

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_add_does_not_reject_cookies_from_a_nested_subdomain
    url = URI 'http://y.x.foo.com'

    cookie = Mechanize::Cookie.new(cookie_values(:domain => '.foo.com'))
    @jar.add(url, cookie)

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_cookie_without_leading_dot_does_not_cause_substring_match
    url = URI 'http://arubyforge.org/'

    cookie = Mechanize::Cookie.new(cookie_values(:domain => 'rubyforge.org'))
    @jar.add(url, cookie)

    assert_equal(0, @jar.cookies(url).length)
  end

  def test_cookie_without_leading_dot_matches_subdomains
    url = URI 'http://admin.rubyforge.org/'

    cookie = Mechanize::Cookie.new(cookie_values(:domain => 'rubyforge.org'))
    @jar.add(url, cookie)

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_cookies_with_leading_dot_match_subdomains
    url = URI 'http://admin.rubyforge.org/'

    @jar.add(url, Mechanize::Cookie.new(cookie_values(:domain => '.rubyforge.org')))

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_cookies_with_leading_dot_match_parent_domains
    url = URI 'http://rubyforge.org/'

    @jar.add(url, Mechanize::Cookie.new(cookie_values(:domain => '.rubyforge.org')))

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_cookies_with_leading_dot_match_parent_domains_exactly
    url = URI 'http://arubyforge.org/'

    @jar.add(url, Mechanize::Cookie.new(cookie_values(:domain => '.rubyforge.org')))

    assert_equal(0, @jar.cookies(url).length)
  end

  def test_cookie_for_ipv4_address_matches_the_exact_ipaddress
    url = URI 'http://192.168.0.1/'

    cookie = Mechanize::Cookie.new(cookie_values(:domain => '192.168.0.1'))
    @jar.add(url, cookie)

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_cookie_for_ipv4_address_does_not_cause_subdomain_match
    url = URI 'http://192.168.0.1/'

    cookie = Mechanize::Cookie.new(cookie_values(:domain => '.0.1'))
    @jar.add(url, cookie)

    assert_equal(0, @jar.cookies(url).length)
  end

  def test_cookie_for_ipv6_address_matches_the_exact_ipaddress
    url = URI 'http://[fe80::0123:4567:89ab:cdef]/'

    cookie = Mechanize::Cookie.new(cookie_values(:domain => '[fe80::0123:4567:89ab:cdef]'))
    @jar.add(url, cookie)

    assert_equal(1, @jar.cookies(url).length)
  end

  def test_cookies_dot
    url = URI 'http://www.host.example/'

    @jar.add(url,
             Mechanize::Cookie.new(cookie_values(:domain => 'www.host.example')))

    url = URI 'http://wwwxhost.example/'
    assert_equal(0, @jar.cookies(url).length)
  end

  def test_clear_bang
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    @jar.add(url, cookie)
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:name => 'Baz')))
    assert_equal(2, @jar.cookies(url).length)

    @jar.clear!

    assert_equal(0, @jar.cookies(url).length)
  end

  def test_save_cookies_yaml
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    s_cookie = Mechanize::Cookie.new(cookie_values(:name => 'Bar',
                                              :expires => nil))

    @jar.add(url, cookie)
    @jar.add(url, s_cookie)
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:name => 'Baz')))

    assert_equal(3, @jar.cookies(url).length)

    in_tmpdir do
      value = @jar.save_as("cookies.yml")
      assert_same @jar, value

      jar = Mechanize::CookieJar.new
      jar.load("cookies.yml")
      assert_equal(2, jar.cookies(url).length)
    end

    assert_equal(3, @jar.cookies(url).length)
  end

  def test_save_session_cookies_yaml
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    s_cookie = Mechanize::Cookie.new(cookie_values(:name => 'Bar',
                                              :expires => nil))

    @jar.add(url, cookie)
    @jar.add(url, s_cookie)
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:name => 'Baz')))

    assert_equal(3, @jar.cookies(url).length)

    in_tmpdir do
      @jar.save_as("cookies.yml", :format => :yaml, :session => true)

      jar = Mechanize::CookieJar.new
      jar.load("cookies.yml")
      assert_equal(3, jar.cookies(url).length)
    end

    assert_equal(3, @jar.cookies(url).length)
  end


  def test_save_cookies_cookiestxt
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    s_cookie = Mechanize::Cookie.new(cookie_values(:name => 'Bar',
                                              :expires => nil))

    @jar.add(url, cookie)
    @jar.add(url, s_cookie)
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:name => 'Baz')))

    assert_equal(3, @jar.cookies(url).length)

    in_tmpdir do
      @jar.save_as("cookies.txt", :cookiestxt)

      assert_match(/\A# (?:Netscape )?HTTP Cookie File$/, File.read("cookies.txt"))

      jar = Mechanize::CookieJar.new
      jar.load("cookies.txt", :cookiestxt)
      assert_equal(2, jar.cookies(url).length)
    end

    in_tmpdir do
      @jar.save_as("cookies.txt", :cookiestxt, :session => true)

      assert_match(/\A# (?:Netscape )?HTTP Cookie File$/, File.read("cookies.txt"))

      jar = Mechanize::CookieJar.new
      jar.load("cookies.txt", :cookiestxt)
      assert_equal(3, jar.cookies(url).length)
    end

    assert_equal(3, @jar.cookies(url).length)
  end

  def test_expire_cookies
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length)

    # Add a second cookie
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:name => 'Baz')))
    assert_equal(2, @jar.cookies(url).length)

    # Make sure we can get the cookie from different paths
    assert_equal(2, @jar.cookies(URI('http://rubyforge.org/login')).length)

    # Expire the first cookie
    @jar.add(url, Mechanize::Cookie.new(
        cookie_values(:expires => Time.now - (10 * 86400))))
    assert_equal(1, @jar.cookies(url).length)

    # Expire the second cookie
    @jar.add(url, Mechanize::Cookie.new(
        cookie_values( :name => 'Baz', :expires => Time.now - (10 * 86400))))
    assert_equal(0, @jar.cookies(url).length)
  end

  def test_session_cookies
    values = cookie_values(:expires => nil)
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length)

    # Add a second cookie
    @jar.add(url, Mechanize::Cookie.new(values.merge(:name => 'Baz')))
    assert_equal(2, @jar.cookies(url).length)

    # Make sure we can get the cookie from different paths
    assert_equal(2, @jar.cookies(URI('http://rubyforge.org/login')).length)

    # Expire the first cookie
    @jar.add(url, Mechanize::Cookie.new(values.merge(:expires => Time.now - (10 * 86400))))
    assert_equal(1, @jar.cookies(url).length)

    # Expire the second cookie
    @jar.add(url, Mechanize::Cookie.new(
        values.merge(:name => 'Baz', :expires => Time.now - (10 * 86400))))
    assert_equal(0, @jar.cookies(url).length)

    # When given a URI with a blank path, CookieJar#cookies should return
    # cookies with the path '/':
    url = URI 'http://rubyforge.org'
    assert_equal '', url.path
    assert_equal(0, @jar.cookies(url).length)
    # Now add a cookie with the path set to '/':
    @jar.add(url, Mechanize::Cookie.new(values.merge( :name => 'has_root_path',
                                          :path => '/')))
    assert_equal(1, @jar.cookies(url).length)
  end

  def test_paths
    values = cookie_values(:path => "/login", :expires => nil)
    url = URI 'http://rubyforge.org/login'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length)

    # Add a second cookie
    @jar.add(url, Mechanize::Cookie.new(values.merge( :name => 'Baz' )))
    assert_equal(2, @jar.cookies(url).length)

    # Make sure we don't get the cookie in a different path
    assert_equal(0, @jar.cookies(URI('http://rubyforge.org/hello')).length)
    assert_equal(0, @jar.cookies(URI('http://rubyforge.org/')).length)

    # Expire the first cookie
    @jar.add(url, Mechanize::Cookie.new(values.merge( :expires => Time.now - (10 * 86400))))
    assert_equal(1, @jar.cookies(url).length)

    # Expire the second cookie
    @jar.add(url, Mechanize::Cookie.new(values.merge( :name => 'Baz',
                                          :expires => Time.now - (10 * 86400))))
    assert_equal(0, @jar.cookies(url).length)
  end

  def test_save_and_read_cookiestxt
    url = URI 'http://rubyforge.org/'

    # Add one cookie with an expiration date in the future
    cookie = Mechanize::Cookie.new(cookie_values)
    @jar.add(url, cookie)
    @jar.add(url, Mechanize::Cookie.new(cookie_values(:name => 'Baz')))
    assert_equal(2, @jar.cookies(url).length)

    in_tmpdir do
      @jar.save_as("cookies.txt", :cookiestxt)
      @jar.clear!

      @jar.load("cookies.txt", :cookiestxt)
    end

    assert_equal(2, @jar.cookies(url).length)
  end

  def test_save_and_read_cookiestxt_with_session_cookies
    url = URI 'http://rubyforge.org/'

    @jar.add(url, Mechanize::Cookie.new(cookie_values(:expires => nil)))

    in_tmpdir do
      @jar.save_as("cookies.txt", :cookiestxt)
      @jar.clear!

      @jar.load("cookies.txt", :cookiestxt)
    end

    assert_equal(0, @jar.cookies(url).length)
  end

  def test_save_and_read_expired_cookies
    url = URI 'http://rubyforge.org/'

    @jar.jar['rubyforge.org'] = {}


    @jar.add url, Mechanize::Cookie.new(cookie_values)

    # HACK no asertion
  end

  def test_ssl_cookies
    # thanks to michal "ocher" ochman for reporting the bug responsible for this test.
    values = cookie_values(:expires => nil)
    values_ssl = values.merge(:name => 'Baz', :domain => "#{values[:domain]}:443")
    url = URI 'https://rubyforge.org/login'

    cookie = Mechanize::Cookie.new(values)
    @jar.add(url, cookie)
    assert_equal(1, @jar.cookies(url).length, "did not handle SSL cookie")

    cookie = Mechanize::Cookie.new(values_ssl)
    @jar.add(url, cookie)
    assert_equal(2, @jar.cookies(url).length, "did not handle SSL cookie with :443")
  end

  def test_secure_cookie
    nurl = URI 'http://rubyforge.org/login'
    surl = URI 'https://rubyforge.org/login'

    ncookie = Mechanize::Cookie.new(cookie_values(:name => 'Foo1'))
    scookie = Mechanize::Cookie.new(cookie_values(:name => 'Foo2', :secure => true))

    @jar.add(nurl, ncookie)
    @jar.add(nurl, scookie)
    @jar.add(surl, ncookie)
    @jar.add(surl, scookie)

    assert_equal('Foo1',      @jar.cookies(nurl).map { |c| c.name }.sort.join(' ') )
    assert_equal('Foo1 Foo2', @jar.cookies(surl).map { |c| c.name }.sort.join(' ') )
  end

  def test_save_cookies_cookiestxt_subdomain
    top_url = URI 'http://rubyforge.org/'
    subdomain_url = URI 'http://admin.rubyforge.org/'

    # cookie1 is for *.rubyforge.org; cookie2 is only for rubyforge.org, no subdomains
    cookie1 = Mechanize::Cookie.new(cookie_values)
    cookie2 = Mechanize::Cookie.new(cookie_values(:name => 'Boo', :for_domain => false))

    @jar.add(top_url, cookie1)
    @jar.add(top_url, cookie2)

    assert_equal(2, @jar.cookies(top_url).length)
    assert_equal(1, @jar.cookies(subdomain_url).length)

    in_tmpdir do
      @jar.save_as("cookies.txt", :cookiestxt)

      jar = Mechanize::CookieJar.new
      jar.load("cookies.txt", :cookiestxt) # HACK test the format
      assert_equal(2, jar.cookies(top_url).length)
      assert_equal(1, jar.cookies(subdomain_url).length)

      # Check that we actually wrote the file correctly (not just that we were
      # able to read what we wrote):
      #
      # * Cookies that only match exactly the domain specified must not have a
      #   leading dot, and must have FALSE as the second field.
      # * Cookies that match subdomains may have a leading dot, and must have
      #   TRUE as the second field.
      cookies_txt = File.readlines("cookies.txt")
      assert_equal(1, cookies_txt.grep( /^rubyforge\.org\tFALSE/ ).length)
      assert_equal(1, cookies_txt.grep( /^\.rubyforge\.org\tTRUE/ ).length)
    end

    assert_equal(2, @jar.cookies(top_url).length)
    assert_equal(1, @jar.cookies(subdomain_url).length)
  end
end
