# coding: utf-8

require 'mechanize/test_case'

class TestMechanizeHttpAuthStore < Mechanize::TestCase

  def setup
    super

    @store = Mechanize::HTTP::AuthStore.new

    @uri = URI.parse 'http://example/'
  end

  def test_add_auth
    @store.add_auth @uri + '/path', 'user', 'pass'

    expected = {
      @uri => {
        nil => ['user', 'pass', nil],
      }
    }

    assert_equal expected, @store.auth_accounts
  end

  def test_add_auth_domain
    @store.add_auth @uri + '/path', 'user1', 'pass', nil, 'domain'

    expected = {
      @uri => {
        nil => %w[user1 pass domain],
      }
    }

    assert_equal expected, @store.auth_accounts

    e = assert_raises ArgumentError do
      @store.add_auth @uri, 'user3', 'pass', 'realm', 'domain'
    end

    assert_equal 'NTLM domain given with realm which NTLM does not use',
                 e.message
  end

  def test_add_auth_realm
    @store.add_auth @uri, 'user1', 'pass'
    @store.add_auth @uri, 'user2', 'pass', 'realm'

    expected = {
      @uri => {
        nil     => ['user1', 'pass', nil],
        'realm' => ['user2', 'pass', nil],
      }
    }

    assert_equal expected, @store.auth_accounts
  end

  def test_add_auth_realm_case
    @store.add_auth @uri, 'user1', 'pass', 'realm'
    @store.add_auth @uri, 'user2', 'pass', 'Realm'

    expected = {
      @uri => {
        'realm' => ['user1', 'pass', nil],
        'Realm' => ['user2', 'pass', nil],
      }
    }

    assert_equal expected, @store.auth_accounts
  end

  def test_add_auth_string
    @store.add_auth "#{@uri}/path", 'user', 'pass'

    expected = {
      @uri => {
        nil => ['user', 'pass', nil],
      }
    }

    assert_equal expected, @store.auth_accounts
  end

  def test_add_default_auth
    _, err = capture_io do
      @store.add_default_auth 'user', 'pass'
    end

    expected = ['user', 'pass', nil]

    assert_equal expected, @store.default_auth

    assert_match 'DISCLOSURE WITHOUT YOUR KNOWLEDGE', err

    capture_io do
      @store.add_default_auth 'user', 'pass', 'realm'
    end

    expected = %w[user pass realm]

    assert_equal expected, @store.default_auth
  end

  def test_credentials_eh
    challenges = [
      Mechanize::HTTP::AuthChallenge.new('Basic',  'realm' => 'r'),
      Mechanize::HTTP::AuthChallenge.new('Digest', 'realm' => 'r'),
    ]

    refute @store.credentials? @uri, challenges

    @store.add_auth @uri, 'user', 'pass'

    assert @store.credentials? @uri, challenges
    assert @store.credentials? "#{@uri}/path", challenges
  end

  def test_credentials_for
    assert_nil @store.credentials_for(@uri, 'realm')

    @store.add_auth @uri, 'user', 'pass', 'realm'

    assert_equal ['user', 'pass', nil], @store.credentials_for(@uri, 'realm')
    assert_equal ['user', 'pass', nil],
                 @store.credentials_for(@uri.to_s, 'realm')
    assert_nil @store.credentials_for(@uri, 'other')
  end

  def test_credentials_for_default
    assert_nil @store.credentials_for(@uri, 'realm')

    capture_io do
      @store.add_default_auth 'user1', 'pass'
    end

    assert_equal ['user1', 'pass', nil], @store.credentials_for(@uri, 'realm')

    @store.add_auth @uri, 'user2', 'pass'

    assert_equal ['user2', 'pass', nil], @store.credentials_for(@uri, 'realm')
    assert_equal ['user2', 'pass', nil], @store.credentials_for(@uri, 'other')
  end

  def test_credentials_for_no_realm
    @store.add_auth @uri, 'user', 'pass' # no realm set

    assert_equal ['user', 'pass', nil], @store.credentials_for(@uri, 'realm')
  end

  def test_credentials_for_realm
    @store.add_auth @uri, 'user1', 'pass'
    @store.add_auth @uri, 'user2', 'pass', 'realm'

    assert_equal ['user2', 'pass', nil], @store.credentials_for(@uri, 'realm')
    assert_equal ['user1', 'pass', nil], @store.credentials_for(@uri, 'other')
  end

  def test_credentials_for_realm_case
    @store.add_auth @uri, 'user1', 'pass', 'realm'
    @store.add_auth @uri, 'user2', 'pass', 'Realm'

    assert_equal ['user1', 'pass', nil], @store.credentials_for(@uri, 'realm')
    assert_equal ['user2', 'pass', nil], @store.credentials_for(@uri, 'Realm')
  end

  def test_credentials_for_path
    @store.add_auth @uri, 'user', 'pass', 'realm'

    uri = @uri + '/path'

    assert_equal ['user', 'pass', nil], @store.credentials_for(uri, 'realm')
  end

  def test_remove_auth
    @store.remove_auth @uri

    assert_empty @store.auth_accounts
  end

  def test_remove_auth_both
    @store.add_auth @uri, 'user1', 'pass'
    @store.add_auth @uri, 'user2', 'pass', 'realm'

    uri = @uri + '/path'

    @store.remove_auth uri

    assert_empty @store.auth_accounts
  end

  def test_remove_auth_realm
    @store.add_auth @uri, 'user1', 'pass'
    @store.add_auth @uri, 'user2', 'pass', 'realm'

    @store.remove_auth @uri, 'realm'

    expected = {
      @uri => {
        nil => ['user1', 'pass', nil]
      }
    }

    assert_equal expected, @store.auth_accounts
  end

  def test_remove_auth_realm_case
    @store.add_auth @uri, 'user1', 'pass', 'realm'
    @store.add_auth @uri, 'user2', 'pass', 'Realm'

    @store.remove_auth @uri, 'Realm'

    expected = {
      @uri => {
        'realm' => ['user1', 'pass', nil]
      }
    }

    assert_equal expected, @store.auth_accounts
  end

  def test_remove_auth_string
    @store.add_auth @uri, 'user1', 'pass'

    @store.remove_auth "#{@uri}/path"

    assert_empty @store.auth_accounts
  end

end

