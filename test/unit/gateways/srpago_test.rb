require 'test_helper'

class SrpagoTest < Test::Unit::TestCase
  def setup
    @gateway = SrpagoGateway.new(apì_key: "X", api_secret: "Y")
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :first_name => 'Steve',
      :last_name  => 'Smith',
      :month      => '9',
      :year       => '2014',
      :brand       => 'visa',
      :number     => '4242424242424242',
      :verification_value => '123'
    )
    @declined_credit_card = ActiveMerchant::Billing::CreditCard.new(
      :first_name => 'Steve',
      :last_name  => 'Smith',
      :month      => '9',
      :year       => '2014',
      :brand       => 'visa',
      :number     => '3768171111111111',
      :verification_value => '123'
    )
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_request).at_most(2).returns(successful_login_response,successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "Success", response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).at_most(2).returns(successful_login_response,failed_purchase_response)

    response = @gateway.purchase(@amount, @declined_credit_card, @options)
    assert_failure response
    assert_equal "51", response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_request).at_most(2).returns(successful_login_response,successful_void_response)

    response = @gateway.void("NDcxNjYz", @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "Success", response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).at_most(2).returns(successful_login_response,failed_void_response)

    response = @gateway.void("NDcxNjYz", @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "InvalidAuthCodeException", response.error_code
    
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).at_most(3).returns(successful_login_response,successful_purchase_response,successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal "Success", response.message
    assert response.test?
  end


  def test_failed_verify
    @gateway.expects(:ssl_request).at_most(2).returns(successful_login_response,failed_purchase_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal "51", response.error_code
    
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    'opening connection to local.srpagoapi:80...
    opened
    <- "POST /v1//auth/login/application HTTP/1.1\r\nContent-Type: application/json\r\nX-User-Agent: {\"agent\" : \"SrPago/ActiveMerchant 1.59.0\", \"user_agent\" : \"{\"bindings_version\":\"1.59.0\",\"lang\":\"ruby\",\"lang_version\":\"2.3.0 p0 (2015-12-25)\",\"platform\":\"x86_64-darwin14\",\"publisher\":\"active_merchant\"}\" }\r\nAuthorization: Basic M2QzODg2OTYtMmQzZC00ODBjLTg0YWYtMGY3NzliNGI3YTIzOnIvN0xtVzJZKSRtMz9qQygvbHcq\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: local.srpagoapi\r\nContent-Length: 60\r\n\r\n"
    <- "{\"application_bundle\":\"com.cobraonline.SrPago\",\"login\":true}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: nginx/1.10.0\r\n"
    -> "Date: Fri, 17 Jun 2016 15:11:29 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Content-Length: 144\r\n"
    -> "Connection: close\r\n"
    -> "X-Powered-By: srpago\r\n"
    -> "X-App-Request: 2016061710112562117200/2016061710112909162900\r\n"
    -> "\r\n"
    reading 144 bytes...
    -> "{\"connection\":{\"token\":\"4a44d6dd3f8a72ca60be26542a6805bad20e81b78efa0e135fb1ca5a7c078788\",\"expires\":\"2016-07-17T10:11:28-05:00\"},\"success\":true}"
    read 144 bytes
    Conn close
    opening connection to local.srpagoapi:80...
    opened
    <- "POST /v1/payment/card HTTP/1.1\r\nContent-Type: application/json\r\nX-User-Agent: {\"agent\" : \"SrPago/ActiveMerchant 1.59.0\", \"user_agent\" : \"{\"bindings_version\":\"1.59.0\",\"lang\":\"ruby\",\"lang_version\":\"2.3.0 p0 (2015-12-25)\",\"platform\":\"x86_64-darwin14\",\"publisher\":\"active_merchant\"}\" }\r\nAuthorization: Bearer 4a44d6dd3f8a72ca60be26542a6805bad20e81b78efa0e135fb1ca5a7c078788\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: local.srpagoapi\r\nContent-Length: 1568\r\n\r\n"
    <- "{\"key\":\"G7YuX1r6EGd9tjKQHUiksAhSo+HUzH1ZAYvB+BjsVa37k5mjQ1P+5VHb7O81\\nVylBCVBVNBAmo01YbS1J5qC43ik+kM7fx6bQb/mVmTzLGiYB6Ni8kJYPxfuz\\nErnel2zX4qeLq7QLo+SSX/biaLrdyw4nOqnvFSuIOnVfnsifKOXLpzpk+XN6\\nCiVflEeOQnfRTVoOOSWV422yN4UjxbZIkdgwbaillBRiZfO30F5gWhxSN0/B\\nZ86LA/cMn3f3J4ILMe6fLfRpcKezoDI7egm1DqHxJXNt7z60hMwzQ7EygCIQ\\nKIouSQYi4G6TQbYJI1UcYNA1I53v1S08SPOSZnM8ANpW9bVPaozIAzzcWMNI\\nidBZjir0KsT+WfX7907fMRwiRRAHRN7iUn5wub2MUPyz5bXf98vVg0oV+IDv\\n7VDbafLRmA/oDB/NPQVtNVs2NSJabzN8DGp1k2VfiTqSjPLgXclsamrO58gs\\n/5CYuaeEQdM10rb4zjJBw3CoECF0Hos7ElnxJHwTXZAbwjbqZwLtcZZTsW8e\\nt5ZCvAGyhJ3wvMIEZwbGNUt5yUMAM6KMbnXyiWmH1OpIgl2Hf32f6AffsqeW\\n06ssIw4mnAJxEmEz74R63G1ky4GiW1aswHeeknezSPaKwdQFSH7tw9MM2MGG\\n4v/94gIeNC/iUR52Gvu9Q0k=\\n\",\"data\":\"g/4/PlBDezOarAfS2vB9Vc2WP/T1TaJDpa1jH6hK4KRgdMtpgnSC7vqX2ahl\\nuNKzbh3JLwREGI4DCu3TnpNL8bcf10SviBCEOu6nEHxtgRXli2CBsyVpbhcq\\nh8lT/Rp4Pb3RRfZZ9cc6ysFv0GrAyBhmOxXWbOmc1Eyh9pGZ0HCEpD0PuRch\\n4ZRZa8w5QIu5Nko6LTu+8ikZeZ78UZV1sj0wnudGlcGMUHjQLexaXrkg4p3w\\nnsLTOxAO+FbrXVHB7dLf+oG9l0GgHu4OLiLrRwrQvKWxHXYjpMJvjFBlBhYY\\n0C0aYxfPxi0dyySdBc6MbLfRZSBSowSCEyGtJOeR1dq8njc8dq+ZnxNLWwNJ\\n8hs0bTHC011X+X9dsPEBfGd3FcNa+irFt1VI7QEYgRfO7cF0CELRYD6pyjfA\\nycuuOryvCnVVrL2GMRBo9EJXKRIQ8UKsL3GDQJLgpzczqIGyOxJSldGtyX+U\\nz5PqIYcj1Q9ShRH4jQja/O2pCMi15GG/84katYO5utp8YoNsd/sHoDNKs4PZ\\nHsEZgQJWrBSzTlCAvr7G1H19eS8nozMW6dbJNQMpKU3jsJN8EdRyhXxSlPiK\\nALC9nd6jWCqRk877E40AecipL0vRXL5Di+obyqDiLkdZaTznkepJkXKtVA2T\\nJ4sLUDuipk5WEiLColx8vARKKJUQ05hL+wO8r5mlwCHrA01d1Knv9mXegspt\\nXFOcWYheyduCTyfTa6DvjI7kdIWf1xvz/Z9AJu3VAj59BBHGqprdUcuVTADh\\nJpilLyZtlzC0RsAusHgN+Q0XpSUsMa0=\\n\"}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: nginx/1.10.0\r\n"
    -> "Date: Fri, 17 Jun 2016 15:11:35 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Content-Length: 764\r\n"
    -> "Connection: close\r\n"
    -> "X-Powered-By: srpago\r\n"
    -> "X-App-Request: 2016061710112910728300/2016061710113536925500\r\n"
    -> "\r\n"
    reading 764 bytes...
    -> "{\"success\":true,\"result\":{\"token\":\"6e1ae97c-a4ed-4510-867a-cee9f8005a81\",\"status\":true,\"method\":\"CARD\",\"autorization_code\":\"2075462680\",\"card\":\"400010XXXXXX9134\",\"recipe\":{\"transaction\":\"NDcxODU2\",\"timestamp\":\"2016-06-17T10:11:33-05:00\",\"payment_method\":\"POS\",\"authorization_code\":\"2075462680\",\"status\":\"N\",\"reference\":{\"description\":\"Store Purchase\"},\"card\":{\"holder_name\":\"Longbob Longsen\",\"type\":\"VISA\",\"number\":\"9134\",\"label\":\"\"},\"total\":{\"amount\":\"100.00\",\"currency\":\"MXN\"},\"tip\":{\"amount\":\"0.00\",\"currency\":\"MXN\"},\"origin\":{\"location\":{\"latitude\":0,\"longitude\":0}},\"affiliation\":\"7209434\",\"transaction_type\":\"E\",\"url\":\"https:\\/\\/sandbox-connect.srpago.com\\/recipe\\/MTQ2OWI2ODktMGIxZC00ZDZmLWI0M2QtY2JkMjVkYjE2MzQx\",\"hasDevolution\":false},\"card_type\":\"VISA\"}}"
    read 764 bytes
    Conn close'

  end

  def post_scrubbed
    'opening connection to local.srpagoapi:80...
    opened
    <- "POST /v1//auth/login/application HTTP/1.1\r\nContent-Type: application/json\r\nX-User-Agent: {\"agent\" : \"SrPago/ActiveMerchant 1.59.0\", \"user_agent\" : \"{\"bindings_version\":\"1.59.0\",\"lang\":\"ruby\",\"lang_version\":\"2.3.0 p0 (2015-12-25)\",\"platform\":\"x86_64-darwin14\",\"publisher\":\"active_merchant\"}\" }\r\nAuthorization: Basic [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: local.srpagoapi\r\nContent-Length: 60\r\n\r\n"
    <- "{\"application_bundle\":\"com.cobraonline.SrPago\",\"login\":true}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: nginx/1.10.0\r\n"
    -> "Date: Fri, 17 Jun 2016 15:11:29 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Content-Length: 144\r\n"
    -> "Connection: close\r\n"
    -> "X-Powered-By: srpago\r\n"
    -> "X-App-Request: 2016061710112562117200/2016061710112909162900\r\n"
    -> "\r\n"
    reading 144 bytes...
    -> "{\"connection\":{\"token\":\"[FILTERED]\",\"expires\":\"2016-07-17T10:11:28-05:00\"},\"success\":true}"
    read 144 bytes
    Conn close
    opening connection to local.srpagoapi:80...
    opened
    <- "POST /v1/payment/card HTTP/1.1\r\nContent-Type: application/json\r\nX-User-Agent: {\"agent\" : \"SrPago/ActiveMerchant 1.59.0\", \"user_agent\" : \"{\"bindings_version\":\"1.59.0\",\"lang\":\"ruby\",\"lang_version\":\"2.3.0 p0 (2015-12-25)\",\"platform\":\"x86_64-darwin14\",\"publisher\":\"active_merchant\"}\" }\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: local.srpagoapi\r\nContent-Length: 1568\r\n\r\n"
    <- "{\"key\":\"G7YuX1r6EGd9tjKQHUiksAhSo+HUzH1ZAYvB+BjsVa37k5mjQ1P+5VHb7O81\\nVylBCVBVNBAmo01YbS1J5qC43ik+kM7fx6bQb/mVmTzLGiYB6Ni8kJYPxfuz\\nErnel2zX4qeLq7QLo+SSX/biaLrdyw4nOqnvFSuIOnVfnsifKOXLpzpk+XN6\\nCiVflEeOQnfRTVoOOSWV422yN4UjxbZIkdgwbaillBRiZfO30F5gWhxSN0/B\\nZ86LA/cMn3f3J4ILMe6fLfRpcKezoDI7egm1DqHxJXNt7z60hMwzQ7EygCIQ\\nKIouSQYi4G6TQbYJI1UcYNA1I53v1S08SPOSZnM8ANpW9bVPaozIAzzcWMNI\\nidBZjir0KsT+WfX7907fMRwiRRAHRN7iUn5wub2MUPyz5bXf98vVg0oV+IDv\\n7VDbafLRmA/oDB/NPQVtNVs2NSJabzN8DGp1k2VfiTqSjPLgXclsamrO58gs\\n/5CYuaeEQdM10rb4zjJBw3CoECF0Hos7ElnxJHwTXZAbwjbqZwLtcZZTsW8e\\nt5ZCvAGyhJ3wvMIEZwbGNUt5yUMAM6KMbnXyiWmH1OpIgl2Hf32f6AffsqeW\\n06ssIw4mnAJxEmEz74R63G1ky4GiW1aswHeeknezSPaKwdQFSH7tw9MM2MGG\\n4v/94gIeNC/iUR52Gvu9Q0k=\\n\",\"data\":\"g/4/PlBDezOarAfS2vB9Vc2WP/T1TaJDpa1jH6hK4KRgdMtpgnSC7vqX2ahl\\nuNKzbh3JLwREGI4DCu3TnpNL8bcf10SviBCEOu6nEHxtgRXli2CBsyVpbhcq\\nh8lT/Rp4Pb3RRfZZ9cc6ysFv0GrAyBhmOxXWbOmc1Eyh9pGZ0HCEpD0PuRch\\n4ZRZa8w5QIu5Nko6LTu+8ikZeZ78UZV1sj0wnudGlcGMUHjQLexaXrkg4p3w\\nnsLTOxAO+FbrXVHB7dLf+oG9l0GgHu4OLiLrRwrQvKWxHXYjpMJvjFBlBhYY\\n0C0aYxfPxi0dyySdBc6MbLfRZSBSowSCEyGtJOeR1dq8njc8dq+ZnxNLWwNJ\\n8hs0bTHC011X+X9dsPEBfGd3FcNa+irFt1VI7QEYgRfO7cF0CELRYD6pyjfA\\nycuuOryvCnVVrL2GMRBo9EJXKRIQ8UKsL3GDQJLgpzczqIGyOxJSldGtyX+U\\nz5PqIYcj1Q9ShRH4jQja/O2pCMi15GG/84katYO5utp8YoNsd/sHoDNKs4PZ\\nHsEZgQJWrBSzTlCAvr7G1H19eS8nozMW6dbJNQMpKU3jsJN8EdRyhXxSlPiK\\nALC9nd6jWCqRk877E40AecipL0vRXL5Di+obyqDiLkdZaTznkepJkXKtVA2T\\nJ4sLUDuipk5WEiLColx8vARKKJUQ05hL+wO8r5mlwCHrA01d1Knv9mXegspt\\nXFOcWYheyduCTyfTa6DvjI7kdIWf1xvz/Z9AJu3VAj59BBHGqprdUcuVTADh\\nJpilLyZtlzC0RsAusHgN+Q0XpSUsMa0=\\n\"}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Server: nginx/1.10.0\r\n"
    -> "Date: Fri, 17 Jun 2016 15:11:35 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Content-Length: 764\r\n"
    -> "Connection: close\r\n"
    -> "X-Powered-By: srpago\r\n"
    -> "X-App-Request: 2016061710112910728300/2016061710113536925500\r\n"
    -> "\r\n"
    reading 764 bytes...
    -> "{\"success\":true,\"result\":{\"token\":\"[FILTERED]\",\"status\":true,\"method\":\"CARD\",\"autorization_code\":\"[FILTERED]\",\"card\":\"[FILTERED]\",\"recipe\":{\"transaction\":\"[FILTERED]\",\"timestamp\":\"2016-06-17T10:11:33-05:00\",\"payment_method\":\"POS\",\"authorization_code\":\"[FILTERED]\",\"status\":\"N\",\"reference\":{\"description\":\"Store Purchase\"},\"card\":{\"holder_name\":\"Longbob Longsen\",\"type\":\"[FILTERED]\",\"number\":\"[FILTERED]\",\"label\":\"\"},\"total\":{\"amount\":\"100.00\",\"currency\":\"MXN\"},\"tip\":{\"amount\":\"0.00\",\"currency\":\"MXN\"},\"origin\":{\"location\":{\"latitude\":0,\"longitude\":0}},\"affiliation\":\"[FILTERED]\",\"transaction_type\":\"[FILTERED]\",\"url\":\"https:\\/\\/sandbox-connect.srpago.com\\/recipe\\/MTQ2OWI2ODktMGIxZC00ZDZmLWI0M2QtY2JkMjVkYjE2MzQx\",\"hasDevolution\":false},\"card_type\":\"[FILTERED]\"}}"
    read 764 bytes
    Conn close'
  end
  
  def successful_purchase_response
   
    {
      "success"=>true, 
      "result"=>
        { 
          "token"=>"288b0dd0-ca67-4200-b44f-7ab53f5c4a83", 
          "transaction"=>1, 
          "status"=>true, 
          "method"=>"CARD", 
          "autorization_code"=>"1496655002", 
                   
          "card"=>"424242XXXXXX4242", 
          "recipe"=>
            {
              "transaction"=>"NDcxNjYz", 
              "timestamp"=>"2016-06-15T16:00:43-05:00", 
              "payment_method"=>"POS", 
              "authorization_code"=>"1496655002", 
              "status"=>"N", 
              "reference"=>
                {
                  "description"=>"prueba activemerchant"
                }, 
              "card"=>
                {
                  "holder_name"=>"Steve Smith", 
                  "type"=>"VISA", 
                  "number"=>"5515", 
                  "label"=>""
                }, 
              "total"=>
                {
                  "amount"=>"100.00", 
                  "currency"=>"MXN"
                }, 
              "tip"=>
                {
                  "amount"=>"0.00", 
                  "currency"=>"MXN"
                }, 
              "origin"=>
                {
                  "location"=>
                    {
                      "latitude"=>0, 
                      "longitude"=>0
                    }
                }, 
              "affiliation"=>"7209434", 
              "transaction_type"=>"E", 
              "url"=>"https://sandbox-connect.srpago.com/recipe/MWM5M2EwZjQtMGM3Yy00NmQxLWJiZWItODI3MTgwNjUwOWZj", 
              "hasDevolution"=>false
            }, 
          "card_type"=>"VISA"          
        }
    }.to_json
  end
  
  def successful_login_response
    {
      'success' => true,
      'connection' =>
        {
          'token' => 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
          'expires' => (Date.today() +1).strftime
        }    
    }.to_json
  end

  def failed_purchase_response
    {
      "success"=>false, 
      "error"=>
        {
          "code"=>"PaymentException",
          "message"=>"No se pudo procesar el cobro",
          "description"=>"No se pudo procesar el cobro",
          "detail"=>
            {
              "code"=>"51", 
              "message"=>"Tarjeta declinada por el banco, fondos insuficientes", 
              "http_status_code"=>500
            }
        }
    }.to_json
  end

  def successful_void_response
    {
      "success"=>true, 
      "result"=>
        {
          "token"=>"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", 
          "transaction"=>"1", 
          "status"=>true, 
          "method"=>"Reversal", 
          "autorization_code"=>"XXXXXXXXXX", 
          "card"=>"424242XXXXXX4242", 
          "card_type"=>"VISA"
        }
    }.to_json
  end

  def failed_void_response
    {
      "success"=>false, 
      "error"=>
        {
          "code"=>"InvalidAuthCodeException", 
          "message"=>"Solo se pueden cancelar movimientos realizados el mismo dia", 
          "description"=>"Solo se pueden cancelar movimientos realizados el mismo dia"
        }
    }.to_json
  end
 
  
end

