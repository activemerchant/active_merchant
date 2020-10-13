# -*- coding: utf-8 -*-
require 'helper'

class TestWebRobots < Test::Unit::TestCase
  context "robots.txt with no rules" do
    setup do
      @robots = WebRobots.new('RandomBot', :http_get => lambda { |uri|
          case uri.to_s
          when 'http://site1.example.org/robots.txt'
            <<-'TXT'
            TXT
          when 'http://site2.example.org/robots.txt'
            <<-'TXT'

  
            TXT
          when 'http://site3.example.org/robots.txt'
            <<-'TXT'

  #comment
            TXT
          when 'http://site4.example.org/robots.txt'
            <<-'TXT'

  #comment
	
            TXT
          else
            raise "#{uri} is not supposed to be fetched"
          end
        })
    end

    should "be treated as full allow" do
      assert @robots.allowed?('http://site1.example.org/index.html')
      assert @robots.allowed?('http://site1.example.org/private/secret.txt')
      assert @robots.allowed?('http://site2.example.org/index.html')
      assert @robots.allowed?('http://site2.example.org/private/secret.txt')
      assert @robots.allowed?('http://site3.example.org/index.html')
      assert @robots.allowed?('http://site3.example.org/private/secret.txt')
      assert @robots.allowed?('http://site4.example.org/index.html')
      assert @robots.allowed?('http://site4.example.org/private/secret.txt')
    end
  end

  context "the default http_get proc" do
    setup do
      @robots = WebRobots.new('SomeBot')
      @site_uri = URI('http://example.com/')
      @txt_uri  = @site_uri + '/robots.txt'
    end

    should "treat 201 as success" do
      stub_request(:get, @txt_uri).to_return(status: 201, body: '# Just created!')
      assert_equal '# Just created!', @robots.__send__(:http_get, @txt_uri)
      assert_requested :get, @txt_uri
    end

    should "treat redirects more than 5 times as full allow" do
      redirect_uri = @site_uri + '/redirect'
      stub_request(:get, /\A#{Regexp.quote(@site_uri.to_s)}/).to_return(status: 301, headers: { Location: redirect_uri.to_s })
      assert_equal '', @robots.__send__(:http_get, @txt_uri)
      assert_requested :get, @txt_uri, times: 1
      assert_requested :get, redirect_uri, times: 4
    end

    should "treat 400 as full allow" do
      stub_request(:get, @txt_uri).to_return(status: 400, body: 'Bad Request!')
      assert_equal '', @robots.__send__(:http_get, @txt_uri)
      assert_requested :get, @txt_uri
    end

    should "treat 401 as full allow" do
      stub_request(:get, @txt_uri).to_return(status: 401, body: 'Unauthorized!')
      assert_equal '', @robots.__send__(:http_get, @txt_uri)
      assert_requested :get, @txt_uri
    end

    should "treat 403 as full allow" do
      stub_request(:get, @txt_uri).to_return(status: 403, body: 'Forbidden!')
      assert_equal '', @robots.__send__(:http_get, @txt_uri)
      assert_requested :get, @txt_uri
    end

    should "treat 404 as full allow" do
      stub_request(:get, @txt_uri).to_return(status: 404, body: 'Not Found!')
      assert_equal '', @robots.__send__(:http_get, @txt_uri)
      assert_requested :get, @txt_uri
    end

    should "treat 500 as error after retrying 5 times" do
      stub_request(:get, @txt_uri).to_return(status: 500, body: 'Internal Server Error!')
      assert_raise {
        @robots.__send__(:http_get, @txt_uri)
      }
      assert_requested :get, @txt_uri, times: 5
    end

    should "treat 503 as error after retrying 5 times" do
      stub_request(:get, @txt_uri).to_return(status: 503, body: 'Service Unavailable!')
      assert_raise {
        @robots.__send__(:http_get, @txt_uri)
      }
      assert_requested :get, @txt_uri, times: 5
    end
  end

  context "nil or error from a custom http_get proc" do
    setup do
      @robots = WebRobots.new('RandomBot', :http_get => lambda { |uri|
          case uri.to_s
          when 'http://site1.example.org/robots.txt'
            raise Net::HTTPFatalError.new(
              'Internal Server Error',
              Net::HTTPInternalServerError.new('1.1', '500', 'Internal Server Error'))
          when 'http://site2.example.org/robots.txt'
            require 'timeout'
            Timeout.timeout(0) {}
          when 'http://site3.example.org/robots.txt'
            raise Errno::ECONNREFUSED
          when 'http://site4.example.org/robots.txt'
            raise SocketError, "getaddrinfo: nodename nor servname provided, or not known"
          when 'http://site5.example.org/robots.txt'
            nil
          else
            raise "#{uri} is not supposed to be fetched"
          end
        })
    end

    should "be treated as full disallow" do
      assert @robots.disallowed?('http://site1.example.org/index.html')
      assert @robots.disallowed?('http://site1.example.org/private/secret.txt')
      assert @robots.disallowed?('http://site2.example.org/index.html')
      assert @robots.disallowed?('http://site2.example.org/private/secret.txt')
      assert @robots.disallowed?('http://site3.example.org/index.html')
      assert @robots.disallowed?('http://site3.example.org/private/secret.txt')
      assert @robots.disallowed?('http://site4.example.org/index.html')
      assert @robots.disallowed?('http://site4.example.org/private/secret.txt')
      assert @robots.disallowed?('http://site5.example.org/index.html')
      assert @robots.disallowed?('http://site5.example.org/private/secret.txt')
    end
  end

  context "robots.txt with some rules" do
    setup do
      http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          <<-'TXT'
# Punish evil bots
User-Agent: evil
Disallow: /
Disallow-Not: /	# parser teaser

User-Agent: good
# Be generous to good bots
Disallow: /2heavy/
Allow: /2heavy/*.htm
Disallow: /2heavy/*.htm$

User-Agent: *
Disallow: /2heavy/
Disallow: /index.html
# Allow takes precedence over Disallow if the pattern lengths are the same.
Allow: /index.html
          TXT
        when 'http://www.example.com/robots.txt'
          <<-'TXT'
# Default rule is evaluated last even if it is put first.
User-Agent: *
Disallow: /2heavy/
Disallow: /index.html
# Allow takes precedence over Disallow if the pattern lengths are the same.
Allow: /index.html

# Punish evil bots
User-Agent: evil
Disallow: /

User-Agent: good
# Be generous to good bots
Disallow: /2heavy/
Allow: /2heavy/*.htm
Disallow: /2heavy/*.htm$
          TXT
        when 'http://koster1.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /tmp
          TXT
        when 'http://koster2.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /tmp/
          TXT
        when 'http://koster3.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /a%3cd.html
          TXT
        when 'http://koster4.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /a%3Cd.html
          TXT
        when 'http://koster5.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /a%2fb.html
          TXT
        when 'http://koster6.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /a/b.html
          TXT
        when 'http://koster7.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /%7ejoe/index.html
          TXT
        when 'http://koster8.example.net/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /~joe/index.html
          TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }

      @robots = WebRobots.new('RandomBot', :http_get => http_get)
      @robots_good = WebRobots.new('GoodBot', :http_get => http_get)
      @robots_evil = WebRobots.new('EvilBot', :http_get => http_get)
    end

    should "properly restrict access" do
      assert_nothing_raised {
        assert  @robots_good.allowed?('http://www.example.org/index.html')
      }
      assert !@robots_good.allowed?('http://www.example.org/2heavy/index.php')
      assert  @robots_good.allowed?('http://www.example.org/2HEAVY/index.php')
      assert !@robots_good.allowed?(URI('http://www.example.org/2heavy/index.php'))
      assert  @robots_good.allowed?('http://www.example.org/2heavy/index.html')
      assert  @robots_good.allowed?('http://WWW.Example.Org/2heavy/index.html')
      assert !@robots_good.allowed?('http://www.example.org/2heavy/index.htm')
      assert !@robots_good.allowed?('http://WWW.Example.Org/2heavy/index.htm')

      assert !@robots_evil.allowed?('http://www.example.org/index.html')
      assert !@robots_evil.allowed?('http://www.example.org/2heavy/index.php')
      assert !@robots_evil.allowed?('http://www.example.org/2heavy/index.html')
      assert !@robots_evil.allowed?('http://www.example.org/2heavy/index.htm')

      assert  @robots.allowed?('http://www.example.org/index.html')
      assert !@robots.allowed?('http://www.example.org/2heavy/index.php')
      assert !@robots.allowed?('http://www.example.org/2heavy/index.html')
      assert !@robots.allowed?('http://www.example.org/2heavy/index.htm')

      assert  @robots_good.allowed?('http://www.example.com/index.html')
      assert !@robots_good.allowed?('http://www.example.com/2heavy/index.php')
      assert  @robots_good.allowed?('http://www.example.com/2heavy/index.html')
      assert !@robots_good.allowed?('http://www.example.com/2heavy/index.htm')

      assert !@robots_evil.allowed?('http://www.example.com/index.html')
      assert !@robots_evil.allowed?('http://www.example.com/2heavy/index.php')
      assert !@robots_evil.allowed?('http://www.example.com/2heavy/index.html')
      assert !@robots_evil.allowed?('http://www.example.com/2heavy/index.htm')

      assert  @robots.allowed?('http://www.example.com/index.html')
      assert !@robots.allowed?('http://www.example.com/2heavy/index.php')
      assert !@robots.allowed?('http://www.example.com/2heavy/index.html')
      assert !@robots.allowed?('http://www.example.com/2heavy/index.htm')
    end

    should "follow what is said in Koster's draft" do
      assert  @robots.disallowed?('http://koster1.example.net/tmp')
      assert  @robots.disallowed?('http://koster1.example.net/tmp.html')
      assert  @robots.disallowed?('http://koster1.example.net/tmp/a.html')

      assert !@robots.disallowed?('http://koster2.example.net/tmp')
      assert  @robots.disallowed?('http://koster2.example.net/tmp/')
      assert  @robots.disallowed?('http://koster2.example.net/tmp/a.html')

      assert  @robots.disallowed?('http://koster3.example.net/a%3cd.html')
      assert  @robots.disallowed?('http://koster3.example.net/a%3Cd.html')

      assert  @robots.disallowed?('http://koster4.example.net/a%3cd.html')
      assert  @robots.disallowed?('http://koster4.example.net/a%3Cd.html')

      assert  @robots.disallowed?('http://koster5.example.net/a%2fb.html')
      assert !@robots.disallowed?('http://koster5.example.net/a/b.html')

      assert !@robots.disallowed?('http://koster6.example.net/a%2fb.html')
      assert  @robots.disallowed?('http://koster6.example.net/a/b.html')

      assert  @robots.disallowed?('http://koster7.example.net/~joe/index.html')

      assert  @robots.disallowed?('http://koster8.example.net/%7Ejoe/index.html')
    end
  end

  context "robots.txt with errors" do
    setup do
      @turn1 = @turn2 = 0
      @http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          if (@turn1 += 1) % 2 == 1
            <<-'TXT'
# some comment
User-Agent: thebot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html

User-Agent: anotherbot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
            TXT
          else
            <<-'TXT'
# some comment
User-Agent: thebot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
#
User-Agent: anotherbot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
            TXT
          end
        when 'http://www.example.com/robots.txt'
          if (@turn2 += 1) % 2 == 1
            <<-'TXT'
# some comment
#User-Agent: thebot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html

User-Agent: anotherbot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
            TXT
          else
            <<-'TXT'
# some comment
User-Agent: thebot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html

User-Agent: anotherbot
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
            TXT
          end
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }
    end

    should "raise ParseError" do
      robots = WebRobots.new('TheBot', :http_get => @http_get)

      url = 'http://www.example.org/2heavy/index.php'

      assert_nil robots.error(url)
      assert !robots.allowed?(url)
      assert_nothing_raised {
        robots.error!(url)
      }

      robots.reset(url)

      assert robots.allowed?(url)
      error = robots.error(url)
      assert_instance_of WebRobots::ParseError, error
      assert_equal URI('http://www.example.org/'), error.site
      assert_raise(WebRobots::ParseError) {
        robots.error!(url)
      }

      robots.reset(url)

      assert_nil robots.error(url)
      assert !robots.allowed?(url)
      assert_nothing_raised {
        robots.error!(url)
      }

      url = 'http://www.example.com/2heavy/index.php'

      assert robots.allowed?(url)
      assert_instance_of WebRobots::ParseError, robots.error(url)
      assert_raise(WebRobots::ParseError) {
        robots.error!(url)
      }

      robots.reset(url)

      assert_nil robots.error(url)
      assert !robots.allowed?(url)
      assert_nothing_raised {
        robots.error!(url)
      }

      robots.reset(url)

      assert robots.allowed?(url)
      assert_instance_of WebRobots::ParseError, robots.error(url)
      assert_raise(WebRobots::ParseError) {
        robots.error!(url)
      }
    end
  end

  context "robots.txt with options" do
    setup do
      http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          <<-'TXT'
Sitemap: http://www.example.org/sitemap-host1.xml
Sitemap: http://www.example.org/sitemap-host2.xml

User-Agent: MyBot
Disallow: /2heavy/
Allow: /2heavy/*.html
Option1: Foo
Option2: Hello
Crawl-Delay: 1.5

User-Agent: HerBot
Disallow: /2heavy/
Allow: /2heavy/*.html
Option1: Baz
Option2: Qux

User-Agent: *
Disallow: /2heavy/
Allow: /2heavy/*.html
# These are wrong but should be allowed
Allow: /2heavy/%
Crawl-Delay:
#
Option1: Bar
Option3: Hi
          TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }

      @robots_mybot = WebRobots.new('MyBot', :http_get => http_get)
      @robots_mybot_ignore = WebRobots.new('MyBot', :http_get => http_get, :crawl_delay => :ignore)
      @robots_mybot_custom = WebRobots.new('MyBot', :http_get => http_get, :crawl_delay => proc { |*args| @delay_args = args })
      @robots_herbot = WebRobots.new('HerBot', :http_get => http_get)
      @robots_hisbot = WebRobots.new('HisBot', :http_get => http_get)
    end

    should "be properly read" do
      options = @robots_mybot.options('http://www.example.org/')
      assert_equal 2, options.size
      assert_equal 'Foo',   @robots_mybot.option('http://www.example.org/', 'Option1')
      assert_equal 'Foo',   options['option1']
      assert_equal 'Hello', @robots_mybot.option('http://www.example.org/', 'Option2')
      assert_equal 'Hello', options['option2']

      options = @robots_mybot_ignore.options('http://www.example.org/')
      assert_equal 2, options.size
      assert_equal 'Foo',   @robots_mybot_ignore.option('http://www.example.org/', 'Option1')
      assert_equal 'Foo',   options['option1']
      assert_equal 'Hello', @robots_mybot_ignore.option('http://www.example.org/', 'Option2')
      assert_equal 'Hello', options['option2']

      options = @robots_mybot_custom.options('http://www.example.org/')
      assert_equal 2, options.size
      assert_equal 'Foo',   @robots_mybot_custom.option('http://www.example.org/', 'Option1')
      assert_equal 'Foo',   options['option1']
      assert_equal 'Hello', @robots_mybot_custom.option('http://www.example.org/', 'Option2')
      assert_equal 'Hello', options['option2']

      options = @robots_herbot.options('http://www.example.org/')
      assert_equal 2, options.size
      assert_equal 'Baz',   @robots_herbot.option('http://www.example.org/', 'Option1')
      assert_equal 'Baz',   options['option1']
      assert_equal 'Qux',    @robots_herbot.option('http://www.example.org/', 'Option2')
      assert_equal 'Qux',    options['option2']

      options = @robots_hisbot.options('http://www.example.org/')
      assert_equal 2, options.size
      assert_equal 'Bar',   @robots_hisbot.option('http://www.example.org/', 'Option1')
      assert_equal 'Bar',   options['option1']
      assert_equal 'Hi',    @robots_hisbot.option('http://www.example.org/', 'Option3')
      assert_equal 'Hi',    options['option3']

      assert_equal %w[
        http://www.example.org/sitemap-host1.xml
        http://www.example.org/sitemap-host2.xml
      ], @robots_mybot.sitemaps('http://www.example.org/')
      assert_equal %w[
        http://www.example.org/sitemap-host1.xml
        http://www.example.org/sitemap-host2.xml
      ], @robots_mybot_ignore.sitemaps('http://www.example.org/')
      assert_equal %w[
        http://www.example.org/sitemap-host1.xml
        http://www.example.org/sitemap-host2.xml
      ], @robots_herbot.sitemaps('http://www.example.org/')
      assert_equal %w[
        http://www.example.org/sitemap-host1.xml
        http://www.example.org/sitemap-host2.xml
      ], @robots_hisbot.sitemaps('http://www.example.org/')

      assert_equal 1.5, @robots_mybot.crawl_delay('http://www.example.org/')
      assert_equal 1.5, @robots_mybot_ignore.crawl_delay('http://www.example.org/')
      assert_equal 1.5, @robots_mybot_custom.crawl_delay('http://www.example.org/')
      assert_equal 0, @robots_herbot.crawl_delay('http://www.example.org/')
      assert_equal 0, @robots_hisbot.crawl_delay('http://www.example.org/')

      t1 = Time.now
      @robots_mybot.allowed?('http://www.example.org/')
      @robots_mybot.allowed?('http://www.example.org/article1.html')
      t2 = Time.now
      assert_in_delta 1.5, t2 - t1, 0.1
      @robots_mybot.allowed?('http://www.example.org/article2.html')
      t3 = Time.now
      assert_in_delta 1.5, t3 - t2, 0.1

      t1 = Time.now
      @robots_mybot_ignore.allowed?('http://www.example.org/')
      @robots_mybot_ignore.allowed?('http://www.example.org/article1.html')
      t2 = Time.now
      assert_in_delta 0, t2 - t1, 0.1
      @robots_mybot_ignore.allowed?('http://www.example.org/article2.html')
      t3 = Time.now
      assert_in_delta 0, t3 - t2, 0.1

      t1 = Time.now
      @robots_mybot_custom.allowed?('http://www.example.org/')
      @robots_mybot_custom.allowed?('http://www.example.org/article1.html')
      t2 = Time.now
      assert_in_delta 0, t2 - t1, 0.1
      assert_instance_of Array, @delay_args
      assert_equal 2, @delay_args.size
      assert_equal 1.5, @delay_args[0]
      assert_instance_of Time, @delay_args[1]
    end
  end

  context "robots.txt with options" do
    setup do
      http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /
          TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }

      @robots = WebRobots.new('RandomBot', :http_get => http_get)
    end

    should "validate URI" do
      assert_raise(ArgumentError) {
        @robots.allowed?('www.example.org/')
      }
      assert_raise(ArgumentError) {
        @robots.allowed?('::/home/knu')
      }
    end
  end

  context "robots.txt in the real world" do
    setup do
      @testbot = WebRobots.new('TestBot')
      @baidubot = WebRobots.new('TestBaiduspider')	# matches Baiduspider
    end

    should "be parsed for major sites" do
      VCR.use_cassette("major_sites") do
        assert_nothing_raised {
          assert !@testbot.allowed?("https://www.google.com/search")
          assert !@testbot.allowed?("https://www.google.com/catalogs")
          assert @testbot.allowed?("https://www.google.com/catalogs/about")
        }
        assert_nothing_raised {
          assert @testbot.allowed?("https://www.yahoo.com/")
          assert !@testbot.allowed?("https://www.yahoo.com/p/foo")
        }
        assert_nothing_raised {
          assert @testbot.allowed?("http://www.apple.com/jp/foo")
          assert !@baidubot.allowed?("http://www.apple.com/jp/foo")
        }
        assert_nothing_raised {
          assert !@testbot.allowed?("https://github.com/login")
        }
      end
    end
  end

  context "meta robots tag" do
    setup do
      @doc = Nokogiri::HTML(<<-HTML)
<html>
  <head>
    <meta name="ROBOTS" content="NOFOLLOW">
    <meta name="Slurp" content="noindex,nofollow">
    <meta name="googlebot" content="noarchive, noindex">
  </head>
  <body>
    test
  </body>
</html>
      HTML
    end

    should "be properly parsed when given in HTML string" do
      assert !@doc.noindex?
      assert  @doc.nofollow?

      assert  @doc.noindex?('slurp')
      assert  @doc.nofollow?('slurp')

      assert  @doc.noindex?('googlebot')
      assert !@doc.nofollow?('googlebot')
      assert  @doc.meta_robots('googlebot').include?('noarchive')
    end
  end
  
  class Agent
    def initialize
      @robots = WebRobots.new 'agent', :http_get => method(:get)
    end

    def get uri
      @robots.allowed? uri

      if uri.request_uri == '/robots.txt' then
        ''
      else
        'content'
      end
    end
  end

  context "embedded in a user-agent" do
    setup do
      @agent = Agent.new
    end

    should "fetch robots.txt" do
      body = @agent.get URI.parse 'http://example/robots.html'

      assert_equal 'content', body
    end
  end

  context "robots.txt with a space at the end of the last line" do
    setup do
      @robots = WebRobots.new('RandomBot', :http_get => lambda { |uri|
        res = case uri.to_s
          when 'http://site1.example.com/robots.txt'
          <<-'TXT'
User-agent: *
Request-rate: 1/30
Disallow: /util/

Sitemap: http://site1.example.com/text/sitemap.xml
 
TXT
        when 'http://site2.example.com/robots.txt'
          <<-'TXT'
User-agent: *
Request-rate: 1/30
Disallow: /util/

Sitemap: http://site2.example.com/text/sitemap.xml 
TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
        # This chomp is actually key to the test.  Remove the final EOL.
        # The final line should be the one ending with the space.
        res.chomp
      })
    end

    should "be properly parsed" do
      assert_equal(["http://site1.example.com/text/sitemap.xml"], @robots.sitemaps("http://site1.example.com/"))
      assert_equal(["http://site2.example.com/text/sitemap.xml"], @robots.sitemaps("http://site2.example.com/"))
    end
  end

  context "robots.txt cache" do
    setup do
      @fetched = false
      @robots = WebRobots.new('RandomBot', :http_get => lambda { |uri|
          case uri.to_s
          when 'http://site1.example.org/robots.txt'
            @fetched = true
            <<-'TXT'
User-Agent: *
Disallow: /foo
TXT
          when 'http://site2.example.org/robots.txt'
            @fetched = true
            nil
          end
        })
    end

    should "persist unless cache is cleared" do
      assert !@fetched
      assert !@robots.allowed?('http://site1.example.org/foo')
      assert  @fetched

      @fetched = false
      assert  @robots.allowed?('http://site1.example.org/bar')
      assert !@fetched
      assert  @robots.allowed?('http://site1.example.org/baz')
      assert !@fetched
      assert !@robots.allowed?('http://site1.example.org/foo')
      assert !@fetched

      @robots.flush_cache
      assert !@fetched
      assert !@robots.allowed?('http://site1.example.org/foo')
      assert  @fetched

      @fetched = false
      assert  @robots.allowed?('http://site1.example.org/bar')
      assert !@fetched
      assert  @robots.allowed?('http://site1.example.org/baz')
      assert !@fetched
      assert !@robots.allowed?('http://site1.example.org/foo')
      assert !@fetched
    end

    should "persist for non-existent robots.txt unless cache is cleared" do
      assert !@fetched
      assert !@robots.allowed?('http://site2.example.org/foo')
      assert  @fetched

      @fetched = false
      assert !@robots.allowed?('http://site2.example.org/bar')
      assert !@fetched
      assert !@robots.allowed?('http://site2.example.org/baz')
      assert !@fetched
      assert !@robots.allowed?('http://site2.example.org/foo')
      assert !@fetched

      @robots.flush_cache
      assert !@fetched
      assert !@robots.allowed?('http://site2.example.org/foo')
      assert  @fetched

      @fetched = false
      assert !@robots.allowed?('http://site2.example.org/bar')
      assert !@fetched
      assert !@robots.allowed?('http://site2.example.org/baz')
      assert !@fetched
      assert !@robots.allowed?('http://site2.example.org/foo')
      assert !@fetched
    end
  end

  context "robots.txt with just user-agent & sitemap and no blank line between them" do
    setup do
      @robots = WebRobots.new('RandomBot', :http_get => lambda { |uri|
        res = case uri.to_s
          when 'http://site1.example.com/robots.txt'
          <<-'TXT'
User-agent: *
Sitemap: http://site1.example.com/text/sitemap.xml
TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      })
    end

    should "be properly parsed" do
      assert @robots.allowed?("http://site1.example.com/foo")
      assert_equal(["http://site1.example.com/text/sitemap.xml"], @robots.sitemaps("http://site1.example.com/"))
    end
  end
end
