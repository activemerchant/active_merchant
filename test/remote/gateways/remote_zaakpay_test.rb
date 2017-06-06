require 'test_helper'

class RemoteZaakpayTest < Test::Unit::TestCase
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

  def test_dump_transcript
    #skip("Transcript scrubbing for this gateway has been tested.")

    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic
    # dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    # transcript = capture_transcript(@gateway) do
    #   @gateway.purchase(@amount, @credit_card, @options)
    # end
    # transcript = @gateway.scrub(transcript)

    # assert_scrubbed(@credit_card.number, transcript)
    # assert_scrubbed(@credit_card.verification_value, transcript)
    # assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction was completed successfully. ', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card2, @options)
    assert_failure response
    assert_equal 'Unfortunately, the transaction has failed. Transaction has failed', response.message
  end

  def test_successful_authorize_and_capture
    # auth = @gateway.authorize(@amount, @credit_card, @options)
    # assert_success auth

    # assert capture = @gateway.capture(nil, auth.authorization)
    # assert_success capture
  end

  def test_failed_authorize
    # response = @gateway.authorize(@amount, @declined_card, @options)
    # assert_failure response
  end

  def test_partial_capture
    # auth = @gateway.authorize(@amount, @credit_card, @options)
    # assert_success auth

    # assert capture = @gateway.capture(@amount-1, auth.authorization)
    # assert_success capture
  end

  def test_failed_capture
    # response = @gateway.capture(nil, '')
    # assert_failure response
  end

  def test_successful_refund
    # purchase = @gateway.purchase(@amount, @credit_card, @options)
    # assert_success purchase

    # assert refund = @gateway.refund(nil, purchase.authorization)
    # assert_success refund
  end

  def test_partial_refund
    # purchase = @gateway.purchase(@amount, @credit_card, @options)
    # assert_success purchase

    # assert refund = @gateway.refund(@amount-1, purchase.authorization)
    # assert_success refund
  end

  def test_failed_refund
    # response = @gateway.refund(nil, '')
    # assert_failure response
  end

  def test_successful_void
    # auth = @gateway.authorize(@amount, @credit_card, @options)
    # assert_success auth

    # assert void = @gateway.void(auth.authorization)
    # assert_success void
  end

  def test_failed_void
    # response = @gateway.void('')
    # assert_failure response
  end

  def test_successful_verify
    # response = @gateway.verify(@credit_card, @options)
    # assert_success response
    # assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  end

  def test_failed_verify
    # response = @gateway.verify(@declined_card, @options)
    # assert_failure response
    # assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
    # assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_invalid_login
    gateway = ZaakpayGateway.new(
      :merchantIdentifier => '',
      :secretKey => ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
