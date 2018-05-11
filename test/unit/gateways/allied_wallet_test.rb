require 'test_helper'

class AlliedWalletTest < Test::Unit::TestCase
  include CommStub

    def setup
      @gateway = AlliedWalletGateway.new(
        site_id: "1234",
        merchant_id: "1234",
        token: "token"
      )

      @credit_card = credit_card
      @amount = 100
    end

    def test_successful_purchase
      response = stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.respond_with(successful_purchase_response)

      assert_success response

      assert_equal "123456", response.authorization
      assert response.test?
    end

    def test_failed_purchase
      response = stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.respond_with(failed_purchase_response)

      assert_failure response
      assert_equal "Declined", response.message
      assert response.test?
    end

    def test_successful_authorize_and_capture
      response = stub_comms do
        @gateway.authorize(@amount, @credit_card)
      end.respond_with(successful_authorize_response)

      assert_success response
      assert_equal "123456", response.authorization

      capture = stub_comms do
        @gateway.capture(@amount, response.authorization)
      end.respond_with(successful_capture_response)

      assert_success capture
    end

    def test_failed_authorize
      response = stub_comms do
        @gateway.authorize(@amount, @credit_card)
      end.respond_with(failed_authorize_response)

      assert_failure response
      assert_equal "Declined", response.message
      assert response.test?
    end

    def test_failed_capture
      response = stub_comms do
        @gateway.capture(100, "")
      end.respond_with(failed_capture_response)

      assert_failure response
    end

    def test_successful_void
      response = stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.respond_with(successful_authorize_response)

      assert_success response
      assert_equal "123456", response.authorization

      void = stub_comms do
        @gateway.void(response.authorization)
      end.check_request do |endpoint, data, headers|
        assert_match(/123456/, data)
      end.respond_with(successful_void_response)

      assert_success void
    end

    def test_failed_void
      response = stub_comms do
        @gateway.void("5d53a33d960c46d00f5dc061947d998c")
      end.check_request do |endpoint, data, headers|
        assert_match(/5d53a33d960c46d00f5dc061947d998c/, data)
      end.respond_with(failed_void_response)

      assert_failure response
    end

    def test_successful_refund
      response = stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.respond_with(successful_purchase_response)

      assert_success response
      assert_equal "123456", response.authorization

      refund = stub_comms do
        @gateway.refund(@amount, response.authorization)
      end.check_request do |endpoint, data, headers|
        assert_match(/123456/, data)
      end.respond_with(successful_refund_response)

      assert_success refund
    end

    def test_failed_refund
      response = stub_comms do
        @gateway.refund(nil, "")
      end.respond_with(failed_refund_response)

      assert_failure response
    end

    def test_successful_verify
      response = stub_comms do
        @gateway.verify(@credit_card)
      end.respond_with(successful_authorize_response, failed_void_response)
      assert_success response
      assert_equal "Succeeded", response.message
    end

    def test_failed_verify
      response = stub_comms do
        @gateway.verify(@credit_card)
      end.respond_with(failed_authorize_response, successful_void_response)
      assert_failure response
      assert_equal "Declined", response.message
    end

    def test_empty_response_fails
      response = stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.respond_with(empty_purchase_response)

      assert_failure response
      assert_equal "Error", response.message
    end

    def test_invalid_json
      response = stub_comms do
        @gateway.purchase(@amount, @credit_card)
      end.respond_with(invalid_json_response)

      assert_failure response
      assert_match %r{Unparsable response}, response.message
    end

    def test_transcript_scrubbing
      assert_equal scrubbed_transcript, @gateway.scrub(transcript)
    end

    def test_nil_cvv_transcript_scrubbing
      assert_equal nil_cvv_scrubbed_transcript, @gateway.scrub(nil_cvv_transcript)
    end

    def test_empty_string_cvv_transcript_scrubbing
      assert_equal empty_string_cvv_scrubbed_transcript, @gateway.scrub(empty_string_cvv_transcript)
    end

    private

    def successful_purchase_response
      %(
      {
        "id": "123456",
        "message": "Success",
        "state": "Sale",
        "status": "Successful"
      }
      )
    end

    def failed_purchase_response
      %(
      {
        "id": "123456",
        "message": "Declined",
        "state": "Sale",
        "status": "Declined"
      }
      )
    end

    def successful_authorize_response
      %(
      {
        "id": "123456",
        "message": "Success",
        "state": "Authorize",
        "status": "Successful"
      }
      )
    end

    def failed_authorize_response
      %(
      {
        "id": "123456",
        "message": "Declined",
        "state": "Authorize",
        "status": "Declined"
      }
      )
    end

    def successful_capture_response
      %(
      {
        "id": "123456",
        "message": "Successful",
        "state": "Capture",
        "status": "Successful"
      }
      )
    end

    def failed_capture_response
      %(
      {
        "id": "123456",
        "message": "Declined",
        "state": "Capture",
        "status": "Declined"
      }
      )
    end

    def successful_void_response
      %(
      {
        "id": "123456",
        "message": "Success",
        "state": "Void",
        "status": "Successful"
      }
      )
    end

    def failed_void_response
      %(
      {
        "id": "123456",
        "message": "Error",
        "state": "Void",
        "status": "Error"
      }
      )
    end

    def successful_refund_response
      %(
      {
        "id": "123456",
        "message": "Success",
        "state": "Refund",
        "status": "Successful"
      }
      )
    end

    def failed_refund_response
      %(
      {
        "id": "123456",
        "message": "Error",
        "state": "Refund",
        "status": "Error"
      }
      )
    end


    def empty_purchase_response
      %(
      {
        "id": "123456",
        "message": "Error",
        "state": "Purchase",
        "status": "Error"
      }
      )
    end

    def invalid_json_response
      %(
      {
        "id": "123456",
      )
    end


    def transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer AAEAAHwXaLTYs2APKJW_4TpTDwCw_h9oDx9rA58FR78AFuYCX82Izes1nz9qGBXELGUN_EukKcP5T78Th5guDz4Rw5dQ4Gf0suKw7pz9vWrqa1NpZhrD9Lj9T-SFtOJgfodiwVaBBeSgbJLKA7MOzC9q2dv91HBNP69DygL1oX2L2mtt8fWlKSWhQmtG040E1I43jTueX3L3L9YA7iO6pIwO7CGybE5LnjkQ65KB2K4oYKfXRZosF77hgMJIh-KprFy9cYY3EjfupHeLon9im1BGafrda2N5wj_A_LvdMzfLAD1l1dgj82KlvM_gAzNJ4S19gAicRo9zIbsq36Apt-8jFjS0AQAAAAEAAA9Zr_lVLKMmmtKSo6T_9ulzMCRbYs798EpFD2wMlkb1NCQtA65VrNcM20Ka2FjNQfwOcSMWqDl9zFQhPyFl-npsG1Ww2oyyavA6HSe1HLRLtE_1hNBAlTBPQnLJ6hBf8eR_NTiVa-aQdV2l92-eSwCS59CzrOYGGCY1pLdNMDr_r66kg9l-l94154kRoMBRQSCqZV9iM9M-f3adLJqG6Q79zz1oJpGrH-Zv1kuv8eLaJJNOEFYARb0JbnAC5G1l9-aqxGvBrNkd4sAJIe23XrRx2XJCBIABxuGSQ1xJBTINVlXBXq1mvvd8B1uiYiDNia3c_vIGuSGIjZE0VbUN3oJppfCt1joGdePeUaC2Pyb2vuUN00EBEOaD9RF8IBWMLVJaF9cW2OewDOfBQg94MuOKLdXB_IisRx1ed25VQDVyv0f0CxmkAidvoDN0vvRIJZJr-bgBuL5FZM7gETAeYeiGlh7-Mf2Hzgy7236YNxcC9OnWFEcKEU50nlqog1bJnk8wJgoJWNqG0NUEK4DUzYqknmZ98qQv6rYrg5V-Hey-jAQp_KNf3h-vFHVZdP26Yg\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"4242424242424242\",\"cVVCode\":\"123\",\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end

    def scrubbed_transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"[FILTERED]\",\"cVVCode\":\"[FILTERED]\",\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end

    def nil_cvv_transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer AAEAAHwXaLTYs2APKJW_4TpTDwCw_h9oDx9rA58FR78AFuYCX82Izes1nz9qGBXELGUN_EukKcP5T78Th5guDz4Rw5dQ4Gf0suKw7pz9vWrqa1NpZhrD9Lj9T-SFtOJgfodiwVaBBeSgbJLKA7MOzC9q2dv91HBNP69DygL1oX2L2mtt8fWlKSWhQmtG040E1I43jTueX3L3L9YA7iO6pIwO7CGybE5LnjkQ65KB2K4oYKfXRZosF77hgMJIh-KprFy9cYY3EjfupHeLon9im1BGafrda2N5wj_A_LvdMzfLAD1l1dgj82KlvM_gAzNJ4S19gAicRo9zIbsq36Apt-8jFjS0AQAAAAEAAA9Zr_lVLKMmmtKSo6T_9ulzMCRbYs798EpFD2wMlkb1NCQtA65VrNcM20Ka2FjNQfwOcSMWqDl9zFQhPyFl-npsG1Ww2oyyavA6HSe1HLRLtE_1hNBAlTBPQnLJ6hBf8eR_NTiVa-aQdV2l92-eSwCS59CzrOYGGCY1pLdNMDr_r66kg9l-l94154kRoMBRQSCqZV9iM9M-f3adLJqG6Q79zz1oJpGrH-Zv1kuv8eLaJJNOEFYARb0JbnAC5G1l9-aqxGvBrNkd4sAJIe23XrRx2XJCBIABxuGSQ1xJBTINVlXBXq1mvvd8B1uiYiDNia3c_vIGuSGIjZE0VbUN3oJppfCt1joGdePeUaC2Pyb2vuUN00EBEOaD9RF8IBWMLVJaF9cW2OewDOfBQg94MuOKLdXB_IisRx1ed25VQDVyv0f0CxmkAidvoDN0vvRIJZJr-bgBuL5FZM7gETAeYeiGlh7-Mf2Hzgy7236YNxcC9OnWFEcKEU50nlqog1bJnk8wJgoJWNqG0NUEK4DUzYqknmZ98qQv6rYrg5V-Hey-jAQp_KNf3h-vFHVZdP26Yg\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"4242424242424242\",\"cVVCode\":null,\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end

    def nil_cvv_scrubbed_transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"[FILTERED]\",\"cVVCode\":[BLANK],\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end

    def empty_string_cvv_transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer AAEAAHwXaLTYs2APKJW_4TpTDwCw_h9oDx9rA58FR78AFuYCX82Izes1nz9qGBXELGUN_EukKcP5T78Th5guDz4Rw5dQ4Gf0suKw7pz9vWrqa1NpZhrD9Lj9T-SFtOJgfodiwVaBBeSgbJLKA7MOzC9q2dv91HBNP69DygL1oX2L2mtt8fWlKSWhQmtG040E1I43jTueX3L3L9YA7iO6pIwO7CGybE5LnjkQ65KB2K4oYKfXRZosF77hgMJIh-KprFy9cYY3EjfupHeLon9im1BGafrda2N5wj_A_LvdMzfLAD1l1dgj82KlvM_gAzNJ4S19gAicRo9zIbsq36Apt-8jFjS0AQAAAAEAAA9Zr_lVLKMmmtKSo6T_9ulzMCRbYs798EpFD2wMlkb1NCQtA65VrNcM20Ka2FjNQfwOcSMWqDl9zFQhPyFl-npsG1Ww2oyyavA6HSe1HLRLtE_1hNBAlTBPQnLJ6hBf8eR_NTiVa-aQdV2l92-eSwCS59CzrOYGGCY1pLdNMDr_r66kg9l-l94154kRoMBRQSCqZV9iM9M-f3adLJqG6Q79zz1oJpGrH-Zv1kuv8eLaJJNOEFYARb0JbnAC5G1l9-aqxGvBrNkd4sAJIe23XrRx2XJCBIABxuGSQ1xJBTINVlXBXq1mvvd8B1uiYiDNia3c_vIGuSGIjZE0VbUN3oJppfCt1joGdePeUaC2Pyb2vuUN00EBEOaD9RF8IBWMLVJaF9cW2OewDOfBQg94MuOKLdXB_IisRx1ed25VQDVyv0f0CxmkAidvoDN0vvRIJZJr-bgBuL5FZM7gETAeYeiGlh7-Mf2Hzgy7236YNxcC9OnWFEcKEU50nlqog1bJnk8wJgoJWNqG0NUEK4DUzYqknmZ98qQv6rYrg5V-Hey-jAQp_KNf3h-vFHVZdP26Yg\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"4242424242424242\",\"cVVCode\":\"\",\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end

    def empty_string_cvv_scrubbed_transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"[FILTERED]\",\"cVVCode\":\"[BLANK]\",\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end

    def whitespace_string_cvv_transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer AAEAAHwXaLTYs2APKJW_4TpTDwCw_h9oDx9rA58FR78AFuYCX82Izes1nz9qGBXELGUN_EukKcP5T78Th5guDz4Rw5dQ4Gf0suKw7pz9vWrqa1NpZhrD9Lj9T-SFtOJgfodiwVaBBeSgbJLKA7MOzC9q2dv91HBNP69DygL1oX2L2mtt8fWlKSWhQmtG040E1I43jTueX3L3L9YA7iO6pIwO7CGybE5LnjkQ65KB2K4oYKfXRZosF77hgMJIh-KprFy9cYY3EjfupHeLon9im1BGafrda2N5wj_A_LvdMzfLAD1l1dgj82KlvM_gAzNJ4S19gAicRo9zIbsq36Apt-8jFjS0AQAAAAEAAA9Zr_lVLKMmmtKSo6T_9ulzMCRbYs798EpFD2wMlkb1NCQtA65VrNcM20Ka2FjNQfwOcSMWqDl9zFQhPyFl-npsG1Ww2oyyavA6HSe1HLRLtE_1hNBAlTBPQnLJ6hBf8eR_NTiVa-aQdV2l92-eSwCS59CzrOYGGCY1pLdNMDr_r66kg9l-l94154kRoMBRQSCqZV9iM9M-f3adLJqG6Q79zz1oJpGrH-Zv1kuv8eLaJJNOEFYARb0JbnAC5G1l9-aqxGvBrNkd4sAJIe23XrRx2XJCBIABxuGSQ1xJBTINVlXBXq1mvvd8B1uiYiDNia3c_vIGuSGIjZE0VbUN3oJppfCt1joGdePeUaC2Pyb2vuUN00EBEOaD9RF8IBWMLVJaF9cW2OewDOfBQg94MuOKLdXB_IisRx1ed25VQDVyv0f0CxmkAidvoDN0vvRIJZJr-bgBuL5FZM7gETAeYeiGlh7-Mf2Hzgy7236YNxcC9OnWFEcKEU50nlqog1bJnk8wJgoJWNqG0NUEK4DUzYqknmZ98qQv6rYrg5V-Hey-jAQp_KNf3h-vFHVZdP26Yg\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"4242424242424242\",\"cVVCode\":\"    \",\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end

    def whitespace_string_cvv_scrubbed_transcript
      %(
      <- "POST /merchants/10090/SALEtransactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.alliedwallet.com\r\nContent-Length: 464\r\n\r\n"
      <- "{\"siteId\":\"10118\",\"amount\":\"1.00\",\"trackingId\":\"82b5f6217fa19daa426e226a231d330a\",\"currency\":\"USD\",\"nameOnCard\":\"Longbob Longsen\",\"cardNumber\":\"[FILTERED]\",\"cVVCode\":\"[BLANK]\",\"expirationYear\":\"2016\",\"expirationMonth\":\"09\",\"email\":\"jim_smith@example.com\",\"iPAddress\":\"127.0.0.1\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"addressLine1\":\"456 My Street\",\"addressLine2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryId\":\"CA\",\"postalCode\":\"K1C2N6\",\"phone\":\"(555)555-5555\"}"
      )
    end
end
