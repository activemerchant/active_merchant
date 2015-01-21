require 'test_helper'

class ConnectionTest < Test::Unit::TestCase

  def setup
    @ok = stub(:code => 200, :message => 'OK', :body => 'success')

    @endpoint   = 'https://example.com/tx.php'
    @connection = ActiveMerchant::Connection.new(@endpoint)
    @connection.logger = stub(:info => nil, :debug => nil, :error => nil)
  end

  def test_connection_endpoint_parses_string_to_uri
    assert_equal URI.parse(@endpoint), @connection.endpoint
  end

  def test_connection_endpoint_accepts_uri
    endpoint = URI.parse(@endpoint)
    connection = ActiveMerchant::Connection.new(endpoint)
    assert_equal endpoint, connection.endpoint
  end

  def test_connection_endpoint_raises_uri_error
    assert_raises URI::InvalidURIError do
      ActiveMerchant::Connection.new("not a URI")
    end
  end

  def test_successful_get_request
    @connection.logger.expects(:info).twice
    Net::HTTP.any_instance.expects(:get).with('/tx.php', {}).returns(@ok)
    response = @connection.request(:get, nil, {})
    assert_equal 'success', response.body
  end

  def test_successful_post_request
    Net::HTTP.any_instance.expects(:post).with('/tx.php', 'data', ActiveMerchant::Connection::RUBY_184_POST_HEADERS).returns(@ok)
    response = @connection.request(:post, 'data', {})
    assert_equal 'success', response.body
  end

  def test_successful_put_request
    Net::HTTP.any_instance.expects(:put).with('/tx.php', 'data', {}).returns(@ok)
    response = @connection.request(:put, 'data', {})
    assert_equal 'success', response.body
  end

  def test_successful_delete_request
    Net::HTTP.any_instance.expects(:delete).with('/tx.php', {}).returns(@ok)
    response = @connection.request(:delete, nil, {})
    assert_equal 'success', response.body
  end

  def test_get_raises_argument_error_if_passed_data
    assert_raises(ArgumentError) do
      @connection.request(:get, 'data', {})
    end
  end

  def test_request_raises_when_request_method_not_supported
    assert_raises(ArgumentError) do
      @connection.request(:head, nil, {})
    end
  end

  def test_override_max_retries
    refute_equal 1, @connection.max_retries
    @connection.max_retries = 1
    assert_equal 1, @connection.max_retries
  end

  def test_override_ssl_version
    refute_equal :SSLv3, @connection.ssl_version
    @connection.ssl_version = :SSLv3
    assert_equal :SSLv3, @connection.ssl_version
  end

  def test_default_read_timeout
    assert_equal ActiveMerchant::Connection::READ_TIMEOUT, @connection.read_timeout
  end

  def test_override_read_timeout
    @connection.read_timeout = 20
    assert_equal 20, @connection.read_timeout
  end

  def test_default_open_timeout
    @connection.open_timeout = 20
    assert_equal 20, @connection.open_timeout
  end

  def test_default_verify_peer
    assert_equal ActiveMerchant::Connection::VERIFY_PEER, @connection.verify_peer
  end

  def test_override_verify_peer
    @connection.verify_peer = false
    assert_equal false, @connection.verify_peer
  end

  def test_default_ca_file_exists
    assert File.exist?(ActiveMerchant::Connection::CA_FILE)
  end

  def test_default_ca_file
    assert_equal ActiveMerchant::Connection::CA_FILE, @connection.ca_file
    assert_equal ActiveMerchant::Connection::CA_FILE, @connection.send(:http).ca_file
  end

  def test_override_ca_file
    @connection.ca_file = "/bogus"
    assert_equal "/bogus", @connection.ca_file
    assert_equal "/bogus", @connection.send(:http).ca_file
  end

  def test_default_ca_path
    assert_equal ActiveMerchant::Connection::CA_PATH, @connection.ca_path
    assert_equal ActiveMerchant::Connection::CA_PATH, @connection.send(:http).ca_path
  end

  def test_override_ca_path
    @connection.ca_path = "/bogus"
    assert_equal "/bogus", @connection.ca_path
    assert_equal "/bogus", @connection.send(:http).ca_path
  end

  def test_unrecoverable_exception
    @connection.logger.expects(:info).once
    Net::HTTP.any_instance.expects(:post).raises(EOFError)

    assert_raises(ActiveMerchant::ConnectionError) do
      @connection.request(:post, '')
    end
  end

  def test_failure_then_success_with_recoverable_exception
    @connection.logger.expects(:info).never
    Net::HTTP.any_instance.expects(:post).times(2).raises(Errno::ECONNREFUSED).then.returns(@ok)

    @connection.request(:post, '')
  end

  def test_failure_limit_reached
    @connection.logger.expects(:info).once
    Net::HTTP.any_instance.expects(:post).times(ActiveMerchant::Connection::MAX_RETRIES).raises(Errno::ECONNREFUSED)

    assert_raises(ActiveMerchant::ConnectionError) do
      @connection.request(:post, '')
    end
  end

  def test_failure_then_success_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(2).raises(EOFError).then.returns(@ok)

    @connection.retry_safe = true

    @connection.request(:post, '')
  end

  def test_mixture_of_failures_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(3).raises(Errno::ECONNRESET).
                                                   raises(Errno::ECONNREFUSED).
                                                   raises(EOFError)

    @connection.retry_safe = true

    assert_raises(ActiveMerchant::ConnectionError) do
      @connection.request(:post, '')
    end
  end

  def test_failure_with_ssl_certificate
    @connection.logger.expects(:error).once
    Net::HTTP.any_instance.expects(:post).raises(OpenSSL::X509::CertificateError)

    assert_raises(ActiveMerchant::ClientCertificateError) do
      @connection.request(:post, '')
    end
  end

end
