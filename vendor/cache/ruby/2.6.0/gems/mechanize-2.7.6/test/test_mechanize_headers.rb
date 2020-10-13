require 'mechanize/test_case'

class TestMechanizeHeaders < Mechanize::TestCase
  def setup
    super

    @headers = Mechanize::Headers.new
    @headers['content-type'] = 'text/html'
    @headers['Content-encoding'] = 'gzip'
    @headers['SERVER'] = 'Apache/2.2'
  end

  def test_aref
    assert_equal('Apache/2.2', @headers['server'])
    assert_equal('text/html', @headers['Content-Type'])
  end

  def test_key?
    assert_equal(true, @headers.key?('content-Encoding'))
  end

  def test_canonical_each
    all_keys = ['Content-Type', 'Content-Encoding', 'Server']
    keys = all_keys.dup
    @headers.canonical_each { |key, value|
      case keys.delete(key)
      when *all_keys
        # ok
      else
        flunk "unexpected key: #{key}"
      end
    }
    assert_equal([], keys)
  end
end
