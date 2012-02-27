require 'test_helper'
#require "net/http"

class RemoteNmiThreeStepTest < Test::Unit::TestCase
  

  def setup
    @gateway = NmiThreeStepGateway.new(fixtures(:nmi_three_step))
    
    @amount = 101
    @declined_amount = 42
    #@credit_card = credit_card('4111111111111111') # Visa
    
    @options = { 
      #:order_id => '1',
      #:billing_address => address,
      #:description => 'Store Purchase',
      :return_url => 'http://example.com'
    }

    @step_two_form_data = {
      "billing-cc-number" => "4111111111111111", # Visa
      "billing-cc-exp" => "1010", # 10/2010
    }
  end
  
  def test_successful_purchase
    # Step 1: submit amount and get form URL for sensitive payment information
    assert response = @gateway.setup_purchase(@amount, @options)
    assert_success response
    assert_equal "Step 1 completed", response.message
    assert @gateway.form_url_for(response).present?

    # Step 2: send credit card number, etc to remote form
    endpoint = URI.parse(@gateway.form_url_for(response))
    z = Net::HTTP.start(endpoint.host, endpoint.port, :use_ssl => true) do |http|
      req = Net::HTTP::Post.new(endpoint.path)
      req.set_form_data(@step_two_form_data)
      http.request(req)
    end

    # Step 3: use token to make purchase
    token = CGI.parse(URI.parse(z["Location"]).query)["token-id"][0]
    assert token.present?, z["Location"]
    assert response = @gateway.purchase(token)
    assert_success response
    assert_equal "SUCCESS", response.message
  end

  def test_unsuccessful_setup_purchase
    assert response = @gateway.setup_purchase(nil, @options)
    assert_failure response
  end

  def test_invalid_login
    gateway = NmiThreeStepGateway.new(:login => 'abc123')
    assert response = gateway.setup_purchase(@amount, @options)
    assert_failure response
    assert response.message.include?("Specified API key not found"), response.inspect
  end
end
