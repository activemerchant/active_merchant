require File.dirname(__FILE__) + '/../test_helper'

class MockResponse
  def body
  end
end

class PostsDataTests < Test::Unit::TestCase
  URL = 'http://example.com'
  
  def setup
    @gateway = SimpleTestGateway.new
  end
  
  def teardown
    SimpleTestGateway.retry_safe = false
  end
  
  def test_single_successful_post
    Net::HTTP.any_instance.expects(:post).once.returns(MockResponse.new)
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '') 
    end
  end
  
  def test_multiple_successful_posts
    responses = [ MockResponse.new, MockResponse.new ]
    Net::HTTP.any_instance.expects(:post).times(2).returns(*responses)
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '')
      @gateway.ssl_post(URL, '') 
    end
  end
  
  def test_unrecoverable_exception
    Net::HTTP.any_instance.expects(:post).raises(EOFError)
    
    assert_raises(ActiveMerchant::ConnectionError) do
      @gateway.ssl_post(URL, '') 
    end
  end
  
  def test_failure_then_success_with_recoverable_exception
    Net::HTTP.any_instance.expects(:post).times(2).raises(Errno::ECONNREFUSED).then.returns(MockResponse.new)
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '')
    end
  end
  
  def test_failure_limit_reached
    Net::HTTP.any_instance.expects(:post).times(ActiveMerchant::PostsData::MAX_RETRIES).raises(Errno::ECONNREFUSED)
    
    assert_raises(ActiveMerchant::ConnectionError) do 
      @gateway.ssl_post(URL, '')
    end
  end
  
  def test_failure_then_success_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(2).raises(EOFError).then.returns(MockResponse.new)
    
    @gateway.retry_safe = true
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '')
    end
  end
  
  def test_mixture_of_failures_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(3).raises(Errno::ECONNRESET).
                                                   raises(Errno::ECONNREFUSED).
                                                   raises(EOFError)
      
    @gateway.retry_safe = true
                                                     
    assert_raises(ActiveMerchant::ConnectionError) do  
      @gateway.ssl_post(URL, '')
    end
  end
  
  def test_setting_ssl_strict_outside_class_definition
    assert_equal SimpleTestGateway.ssl_strict, SubclassGateway.ssl_strict
    SimpleTestGateway.ssl_strict = !SimpleTestGateway.ssl_strict
    assert_equal SimpleTestGateway.ssl_strict, SubclassGateway.ssl_strict
  end

  def test_setting_timeouts
    @gateway.class.open_timeout=50
    @gateway.class.read_timeout=37
    Net::HTTP.any_instance.expects(:post).once.returns(MockResponse.new)
    Net::HTTP.any_instance.expects(:open_timeout=).with(50)
    Net::HTTP.any_instance.expects(:read_timeout=).with(37)

    assert_nothing_raised do
      @gateway.ssl_post(URL, '')
    end
  end
end