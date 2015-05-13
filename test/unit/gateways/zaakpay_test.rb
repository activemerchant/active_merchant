require 'test_helper'
require 'socket'
class ZaakpayTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
    @gateway = ActiveMerchant::Billing::ZaakpayGateway.new(
      :merchantIdentifier => '5c7148b110ee49d7a1a9042db4fbf4ad', #These credentials are for testing only. 
                                                                #For your own merchantidentifier and secret key, 
                                                                #signup here - https://www.zaakpay.com/developers
      :secretKey          => 'e73be5e3e14a4b548948f899ccde5604',
    )

    #Valid credit card credentials
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
                            :first_name         => 'TestUserFirstName',
                            :last_name          => 'TestUserLastName',
                            :number             => '4012888888881881',
                            :month              => Time.now.month,
                            :year               => Time.now.year+1,
                            :verification_value => '123')
    
    #Invalid credit card credentials
    @credit_card2 = ActiveMerchant::Billing::CreditCard.new(
                            :first_name         => 'TestUserFirstName',
                            :last_name          => 'TestUserLastName',
                            :number             => '4012888808881881',
                            :month              => Time.now.month,
                            :year               => Time.now.year+1,
                            :verification_value => '123')
    

    #Amount in Indian paisa
    @amount = 10000


    @options = {
      :orderId            => 'ruby'+Time.now.to_i.to_s, #To make the order id unique. 
                                                                  #Duplicate order ids are not accepted
      :buyerEmail         => 'your@email.here',
      :buyerFirstName     => 'YourName',
      :buyerLastName      => 'LastName',
      :buyerAddress       => 'YourCompleteAddress',
      :buyerCity          => 'City',
      :buyerState         => 'State',
      :buyerCountry       => 'Country',
      :buyerPincode       => '110101',
      :buyerPhoneNumber   => '9999999999',
      :txnType            => '1',
      :zpPayOption        => '1',
      :mode               => '0', # 0 for Testing, 1 for Production
      :currency           => 'INR',
      :merchantIpAddress  => Socket::getaddrinfo(Socket.gethostname,"echo",Socket::AF_INET)[0][3].to_s, # Your IP address here
      :txnDate            => DateTime.now.strftime("%d-%m-%Y").to_s,  
      :purpose            => '1',
      :productDescription => 'BriefDescriptionHere'
    }
    
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response
    
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card2, @options)
    assert_failure response
    
  end



  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  def test_scrub
    # assert @gateway.supports_scrubbing?
    # assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    POST_SCRUBBED
  end

  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_zaakpay_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
