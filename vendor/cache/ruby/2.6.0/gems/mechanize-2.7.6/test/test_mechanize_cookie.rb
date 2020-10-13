require 'mechanize/test_case'

module Enumerable
  def combine
    masks = inject([[], 1]){|(ar, m), e| [ar << m, m << 1 ] }[0]
    all = masks.inject(0){ |al, m| al|m }

    result = []
    for i in 1..all do
      tmp = []
      each_with_index do |e, idx|
        tmp << e unless (masks[idx] & i) == 0
      end
      result << tmp
    end
    result
  end
end

class TestMechanizeCookie < Mechanize::TestCase
  def assert_cookie_parse url, cookie_text, &block
    cookie = nil

    block ||= proc { |p_cookie| cookie = p_cookie }

    exp_re = /The call of Mechanize::Cookie.parse/
    assert_output "", exp_re do
      Mechanize::Cookie.parse(url, cookie_text, &block)
    end

    cookie
  end

  alias silently capture_io

  def test_parse_dates
    url = URI.parse('http://localhost/')

    yesterday = Time.now - 86400

    dates = [ "14 Apr 89 03:20:12",
              "14 Apr 89 03:20 GMT",
              "Fri, 17 Mar 89 4:01:33",
              "Fri, 17 Mar 89 4:01 GMT",
              "Mon Jan 16 16:12 PDT 1989",
              #"Mon Jan 16 16:12 +0130 1989",
              "6 May 1992 16:41-JST (Wednesday)",
              #"22-AUG-1993 10:59:12.82",
              "22-AUG-1993 10:59pm",
              "22-AUG-1993 12:59am",
              "22-AUG-1993 12:59 PM",
              #"Friday, August 04, 1995 3:54 PM",
              #"06/21/95 04:24:34 PM",
              #"20/06/95 21:07",
              #"95-06-08 19:32:48 EDT",
    ]

    dates.each do |date|
      cookie = "PREF=1; expires=#{date}"
      silently do
        Mechanize::Cookie.parse(url, cookie) { |c|
          assert c.expires, "Tried parsing: #{date}"
          assert_equal(true, c.expires < yesterday)
        }
      end
    end
  end

  def test_parse_empty
    cookie_str = 'a=b; ; c=d'

    uri = URI.parse 'http://example'

    assert_cookie_parse uri, cookie_str do |cookie|
      assert_equal 'a', cookie.name
      assert_equal 'b', cookie.value
    end
  end

  def test_parse_no_space
    cookie_str = "foo=bar;Expires=Sun, 06 Nov 2011 00:28:06 GMT;Path=/"

    uri = URI.parse 'http://example'

    assert_cookie_parse uri, cookie_str do |cookie|
      assert_equal 'foo',               cookie.name
      assert_equal 'bar',               cookie.value
      assert_equal '/',                 cookie.path
      assert_equal Time.at(1320539286), cookie.expires
    end
  end

  def test_parse_quoted
    cookie_str =
      "quoted=\"value\"; Expires=Sun, 06 Nov 2011 00:11:18 GMT; Path=/"

    uri = URI.parse 'http://example'

    assert_cookie_parse uri, cookie_str do |cookie|
      assert_equal 'quoted', cookie.name
      assert_equal 'value', cookie.value
    end
  end

  def test_parse_weird_cookie
    cookie = 'n/a, ASPSESSIONIDCSRRQDQR=FBLDGHPBNDJCPCGNCPAENELB; path=/'
    url = URI.parse('http://www.searchinnovation.com/')
    assert_cookie_parse url, cookie do |c|
      assert_equal('ASPSESSIONIDCSRRQDQR', c.name)
      assert_equal('FBLDGHPBNDJCPCGNCPAENELB', c.value)
    end
  end

  def test_double_semicolon
    double_semi = 'WSIDC=WEST;; domain=.williams-sonoma.com; path=/'
    url = URI.parse('http://williams-sonoma.com/')
    assert_cookie_parse url, double_semi do |cookie|
      assert_equal('WSIDC', cookie.name)
      assert_equal('WEST', cookie.value)
    end
  end

  def test_parse_bad_version
    bad_cookie = 'PRETANET=TGIAqbFXtt; Name=/PRETANET; Path=/; Version=1.2; Content-type=text/html; Domain=192.168.6.196; expires=Friday, 13-November-2026  23:01:46 GMT;'
    url = URI.parse('http://localhost/')

    assert_cookie_parse url, bad_cookie do |cookie|
      assert_nil(cookie.version)
    end
  end

  def test_parse_bad_max_age
    bad_cookie = 'PRETANET=TGIAqbFXtt; Name=/PRETANET; Path=/; Max-Age=1.2; Content-type=text/html; Domain=192.168.6.196; expires=Friday, 13-November-2026  23:01:46 GMT;'
    url = URI.parse('http://localhost/')

    assert_cookie_parse url, bad_cookie do |cookie|
      assert_nil(cookie.max_age)
    end
  end

  def test_parse_date_fail
    url = URI.parse('http://localhost/')

    dates = [ 
              "20/06/95 21:07",
    ]

    silently do
      dates.each do |date|
        cookie = "PREF=1; expires=#{date}"
        Mechanize::Cookie.parse(url, cookie) { |c|
          assert_equal(true, c.expires.nil?)
        }
      end
    end
  end

  def test_parse_domain_dot
    url = URI.parse('http://host.example.com/')

    cookie_str = 'a=b; domain=.example.com'

    cookie = assert_cookie_parse url, cookie_str

    assert_equal 'example.com', cookie.domain
    assert cookie.for_domain?
  end

  def test_parse_domain_no_dot
    url = URI.parse('http://host.example.com/')

    cookie_str = 'a=b; domain=example.com'

    cookie = assert_cookie_parse url, cookie_str

    assert_equal 'example.com', cookie.domain
    assert cookie.for_domain?
  end

  def test_parse_domain_none
    url = URI.parse('http://example.com/')

    cookie_str = 'a=b;'

    cookie = assert_cookie_parse url, cookie_str

    assert_equal 'example.com', cookie.domain
    assert !cookie.for_domain?
  end

  def test_parse_max_age
    url = URI.parse('http://localhost/')

    date = 'Mon, 19 Feb 2012 19:26:04 GMT'

    cookie_text = "name=Akinori; expires=#{date}"
    cookie = assert_cookie_parse url, cookie_text
    assert_equal Time.at(1329679564), cookie.expires

    cookie_text = 'name=Akinori; max-age=3600'
    cookie = assert_cookie_parse url, cookie_text
    assert_in_delta Time.now + 3600, cookie.expires, 1

    # Max-Age has precedence over Expires
    cookie_text = "name=Akinori; max-age=3600; expires=#{date}"
    cookie = assert_cookie_parse url, cookie_text

    assert_in_delta Time.now + 3600, cookie.expires, 1

    cookie_text = "name=Akinori; expires=#{date}; max-age=3600"
    cookie = assert_cookie_parse url, cookie_text

    assert_in_delta Time.now + 3600, cookie.expires, 1
  end

  def test_parse_expires_session
    url = URI.parse('http://localhost/')

    [
      'name=Akinori',
      'name=Akinori; expires',
      'name=Akinori; max-age',
      'name=Akinori; expires=',
      'name=Akinori; max-age=',
    ].each { |str|
      cookie = assert_cookie_parse url, str
      assert cookie.session, str
    }

    [
      'name=Akinori; expires=Mon, 19 Feb 2012 19:26:04 GMT',
      'name=Akinori; max-age=3600',
    ].each { |str|
      cookie = assert_cookie_parse url, str
      assert !cookie.session, str
    }
  end

  def test_parse_many
    url = URI 'http://localhost/'
    cookie_str =
      "name=Aaron; Domain=localhost; Expires=Sun, 06 Nov 2011 00:29:51 GMT; Path=/, " \
      "name=Aaron; Domain=localhost; Expires=Sun, 06 Nov 2011 00:29:51 GMT; Path=/, " \
      "name=Aaron; Domain=localhost; Expires=Sun, 06 Nov 2011 00:29:51 GMT; Path=/, " \
      "name=Aaron; Domain=localhost; Expires=Sun, 06 Nov 2011 00:29:51 GMT; Path=/; HttpOnly, " \
      "expired=doh; Expires=Fri, 04 Nov 2011 00:29:51 GMT; Path=/, " \
      "a_path=some_path; Expires=Sun, 06 Nov 2011 00:29:51 GMT; Path=/some_path, " \
      "no_path1=no_path; Expires=Sun, 06 Nov 2011 00:29:52 GMT, no_expires=nope; Path=/, " \
      "no_path2=no_path; Expires=Sun, 06 Nov 2011 00:29:52 GMT; no_expires=nope; Path, " \
      "no_path3=no_path; Expires=Sun, 06 Nov 2011 00:29:52 GMT; no_expires=nope; Path=, " \
      "no_domain1=no_domain; Expires=Sun, 06 Nov 2011 00:29:53 GMT; no_expires=nope, " \
      "no_domain2=no_domain; Expires=Sun, 06 Nov 2011 00:29:53 GMT; no_expires=nope; Domain, " \
      "no_domain3=no_domain; Expires=Sun, 06 Nov 2011 00:29:53 GMT; no_expires=nope; Domain="

    cookies = nil
    silently { cookies = Mechanize::Cookie.parse url, cookie_str }
    assert_equal 13, cookies.length

    name = cookies.find { |c| c.name == 'name' }
    assert_equal "Aaron",             name.value
    assert_equal "/",                 name.path
    assert_equal Time.at(1320539391), name.expires

    a_path = cookies.find { |c| c.name == 'a_path' }
    assert_equal "some_path",         a_path.value
    assert_equal "/some_path",        a_path.path
    assert_equal Time.at(1320539391), a_path.expires

    no_expires = cookies.find { |c| c.name == 'no_expires' }
    assert_equal "nope", no_expires.value
    assert_equal "/",    no_expires.path
    assert_nil           no_expires.expires

    no_path_cookies = cookies.select { |c| c.value == 'no_path' }
    assert_equal 3, no_path_cookies.size
    no_path_cookies.each { |c|
      assert_equal "/",                 c.path,    c.name
      assert_equal Time.at(1320539392), c.expires, c.name
    }

    no_domain_cookies = cookies.select { |c| c.value == 'no_domain' }
    assert_equal 3, no_domain_cookies.size
    no_domain_cookies.each { |c|
      assert !c.for_domain?, c.name
      assert_equal c.domain, url.host, c.name
      assert_equal Time.at(1320539393), c.expires, c.name
    }

    assert cookies.find { |c| c.name == 'expired' }
  end

  def test_parse_valid_cookie
    url = URI.parse('http://rubyforge.org/')
    cookie_params = {}
    cookie_params['expires']   = 'expires=Sun, 27-Sep-2037 00:00:00 GMT'
    cookie_params['path']      = 'path=/'
    cookie_params['domain']    = 'domain=.rubyforge.org'
    cookie_params['httponly']  = 'HttpOnly'
    cookie_value = '12345%7D=ASDFWEE345%3DASda'

    expires = Time.parse('Sun, 27-Sep-2037 00:00:00 GMT')
    
    cookie_params.keys.combine.each do |c|
      cookie_text = "#{cookie_value}; "
      c.each_with_index do |key, idx|
        if idx == (c.length - 1)
          cookie_text << "#{cookie_params[key]}"
        else
          cookie_text << "#{cookie_params[key]}; "
        end
      end

      cookie = assert_cookie_parse url, cookie_text

      assert_equal('12345%7D=ASDFWEE345%3DASda', cookie.to_s)
      assert_equal('/', cookie.path)

      # if expires was set, make sure we parsed it
      if c.find { |k| k == 'expires' }
        assert_equal(expires, cookie.expires)
      else
        assert_nil(cookie.expires)
      end
    end
  end

  def test_parse_valid_cookie_empty_value
    url = URI.parse('http://rubyforge.org/')
    cookie_params = {}
    cookie_params['expires']   = 'expires=Sun, 27-Sep-2037 00:00:00 GMT'
    cookie_params['path']      = 'path=/'
    cookie_params['domain']    = 'domain=.rubyforge.org'
    cookie_params['httponly']  = 'HttpOnly'
    cookie_value = '12345%7D='

    expires = Time.parse('Sun, 27-Sep-2037 00:00:00 GMT')
    
    cookie_params.keys.combine.each do |c|
      cookie_text = "#{cookie_value}; "
      c.each_with_index do |key, idx|
        if idx == (c.length - 1)
          cookie_text << "#{cookie_params[key]}"
        else
          cookie_text << "#{cookie_params[key]}; "
        end
      end
      cookie = assert_cookie_parse url, cookie_text

      assert_equal('12345%7D=', cookie.to_s)
      assert_equal('', cookie.value)
      assert_equal('/', cookie.path)

      # if expires was set, make sure we parsed it
      if c.find { |k| k == 'expires' }
        assert_equal(expires, cookie.expires)
      else
        assert_nil(cookie.expires)
      end
    end
  end

  # If no path was given, use the one from the URL
  def test_cookie_using_url_path
    url = URI.parse('http://rubyforge.org/login.php')
    cookie_params = {}
    cookie_params['expires']   = 'expires=Sun, 27-Sep-2037 00:00:00 GMT'
    cookie_params['path']      = 'path=/'
    cookie_params['domain']    = 'domain=.rubyforge.org'
    cookie_params['httponly']  = 'HttpOnly'
    cookie_value = '12345%7D=ASDFWEE345%3DASda'

    expires = Time.parse('Sun, 27-Sep-2037 00:00:00 GMT')
    
    cookie_params.keys.combine.each do |c|
      next if c.find { |k| k == 'path' }
      cookie_text = "#{cookie_value}; "
      c.each_with_index do |key, idx|
        if idx == (c.length - 1)
          cookie_text << "#{cookie_params[key]}"
        else
          cookie_text << "#{cookie_params[key]}; "
        end
      end

      cookie = assert_cookie_parse url, cookie_text

      assert_equal('12345%7D=ASDFWEE345%3DASda', cookie.to_s)
      assert_equal('/', cookie.path)

      # if expires was set, make sure we parsed it
      if c.find { |k| k == 'expires' }
        assert_equal(expires, cookie.expires)
      else
        assert_nil(cookie.expires)
      end
    end
  end

  # Test using secure cookies
  def test_cookie_with_secure
    url = URI.parse('http://rubyforge.org/')
    cookie_params = {}
    cookie_params['expires']   = 'expires=Sun, 27-Sep-2037 00:00:00 GMT'
    cookie_params['path']      = 'path=/'
    cookie_params['domain']    = 'domain=.rubyforge.org'
    cookie_params['secure']    = 'secure'
    cookie_value = '12345%7D=ASDFWEE345%3DASda'

    expires = Time.parse('Sun, 27-Sep-2037 00:00:00 GMT')
    
    cookie_params.keys.combine.each do |c|
      next unless c.find { |k| k == 'secure' }
      cookie_text = "#{cookie_value}; "
      c.each_with_index do |key, idx|
        if idx == (c.length - 1)
          cookie_text << "#{cookie_params[key]}"
        else
          cookie_text << "#{cookie_params[key]}; "
        end
      end

      cookie = assert_cookie_parse url, cookie_text

      assert_equal('12345%7D=ASDFWEE345%3DASda', cookie.to_s)
      assert_equal('/', cookie.path)
      assert_equal(true, cookie.secure)

      # if expires was set, make sure we parsed it
      if c.find { |k| k == 'expires' }
        assert_equal(expires, cookie.expires)
      else
        assert_nil(cookie.expires)
      end
    end
  end

  def test_parse_cookie_no_spaces
    url = URI.parse('http://rubyforge.org/')
    cookie_params = {}
    cookie_params['expires']   = 'expires=Sun, 27-Sep-2037 00:00:00 GMT'
    cookie_params['path']      = 'path=/'
    cookie_params['domain']    = 'domain=.rubyforge.org'
    cookie_params['httponly']  = 'HttpOnly'
    cookie_value = '12345%7D=ASDFWEE345%3DASda'

    expires = Time.parse('Sun, 27-Sep-2037 00:00:00 GMT')
    
    cookie_params.keys.combine.each do |c|
      cookie_text = "#{cookie_value};"
      c.each_with_index do |key, idx|
        if idx == (c.length - 1)
          cookie_text << "#{cookie_params[key]}"
        else
          cookie_text << "#{cookie_params[key]};"
        end
      end

      cookie = assert_cookie_parse url, cookie_text

      assert_equal('12345%7D=ASDFWEE345%3DASda', cookie.to_s)
      assert_equal('/', cookie.path)

      # if expires was set, make sure we parsed it
      if c.find { |k| k == 'expires' }
        assert_equal(expires, cookie.expires)
      else
        assert_nil(cookie.expires)
      end
    end
  end

  def test_new
    cookie = Mechanize::Cookie.new('key', 'value')
    assert_equal 'key', cookie.name
    assert_equal 'value', cookie.value
    assert_nil cookie.expires

    # Minimum unit for the expires attribute is second
    expires = Time.at((Time.now + 3600).to_i)

    cookie = Mechanize::Cookie.new('key', 'value', :expires => expires.dup)
    assert_equal 'key', cookie.name
    assert_equal 'value', cookie.value
    assert_equal expires, cookie.expires

    cookie = Mechanize::Cookie.new(:value => 'value', :name => 'key', :expires => expires.dup)
    assert_equal 'key', cookie.name
    assert_equal 'value', cookie.value
    assert_equal expires, cookie.expires
  end

  def test_domain=
    url = URI.parse('http://host.dom.example.com:8080/')

    cookie_str = 'a=b; domain=Example.Com'
    cookie = assert_cookie_parse url, cookie_str
    assert 'example.com', cookie.domain

    cookie.domain = DomainName(url.host)
    assert 'host.dom.example.com', cookie.domain

    cookie.domain = 'Dom.example.com'
    assert 'dom.example.com', cookie.domain

    cookie.domain = Object.new.tap { |o|
      def o.to_str
        'Example.com'
      end
    }
    assert 'example.com', cookie.domain
  end

  def test_cookie_httponly
    url = URI.parse('http://rubyforge.org/')
    cookie_params = {}
    cookie_params['httponly']  = 'HttpOnly'
    cookie_value = '12345%7D=ASDFWEE345%3DASda'

    expires = Time.parse('Sun, 27-Sep-2037 00:00:00 GMT')
    
    cookie_params.keys.combine.each do |c|
      cookie_text = "#{cookie_value}; "
      c.each_with_index do |key, idx|
        if idx == (c.length - 1)
          cookie_text << "#{cookie_params[key]}"
        else
          cookie_text << "#{cookie_params[key]}; "
        end
      end

      cookie = assert_cookie_parse url, cookie_text

      assert_equal(true, cookie.httponly)

      
      # if expires was set, make sure we parsed it
      if c.find { |k| k == 'expires' }
        assert_equal(expires, cookie.expires)
      else
        assert_nil(cookie.expires)
      end
    end
  end


end

