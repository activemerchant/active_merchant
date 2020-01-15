require 'test_helper'

class NetworkInternationalTest < Test::Unit::TestCase
  def setup
    @gateway = NetworkInternationalGateway.new(outlet: 'outlet_ref', token: 'token')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '128120', response.authorization
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-'PRE_SCRUBBED'
    opening connection to api-gateway-uat.ngenius-payments.com:443...
    opened
starting SSL for api-gateway-uat.ngenius-payments.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
<- "POST /transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/payment/card HTTP/1.1\r\nContent-Type: application/vnd.ni-payment.v2+json\r\nAccept: application/vnd.ni-payment.v2+json\r\nUser-Agent: ActiveMerchant/1.78.0\r\nX-Client-Ip: \r\nAuthorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIzOTVTT3NDdkZUY3NlRmpqNTNiZy1lbFBsUlJZci00OEUzWmN0eDloZnVRIn0.eyJqdGkiOiJiNmI4OGNiOS0yZDEzLTQ4NGUtOGU1MS1hY2JjOWVkZDYzOTAiLCJleHAiOjE1NzkxMTEwMjAsIm5iZiI6MCwiaWF0IjoxNTc5MTEwNzIwLCJpc3MiOiJodHRwczovL2lkZW50aXR5LnNhbmRib3gubmdlbml1cy1wYXltZW50cy5jb20vYXV0aC9yZWFsbXMvbmkiLCJhdWQiOiI0NWU3MWM5MC1iOTVlLTRiYTgtYmVkYy05YjZiOWExMGFiYTUiLCJzdWIiOiJiMjZlNWNmNi00MDBhLTRkMjItYmEwMy01MzhkMTY3OTg4MzIiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiI0NWU3MWM5MC1iOTVlLTRiYTgtYmVkYy05YjZiOWExMGFiYTUiLCJhdXRoX3RpbWUiOjAsInNlc3Npb25fc3RhdGUiOiJmZTAxYTFiNS1jZDM4LTQ3MTQtOWFlOS0yYzJiNWM4ZWMzNTYiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbXSwicmVhbG1fYWNjZXNzIjp7InJvbGVzIjpbIkNSRUFURV9BVVRIT1JJWkFUSU9OIiwiVklFV19QQVlNRU5UIiwiUkVWRVJTRV9BVVRIT1JJWkFUSU9OIiwiTUFOQUdFX0NBUFRVUkUiLCJNQU5BR0VfSU5WT0lDRVMiLCJWSUVXX0FORF9ET1dOTE9BRF9SRVBPUlRTIiwiVklFV19PUkRFUiIsIk1FUkNIQU5UX1NZU1RFTVMiLCJDUkVBVEVfVkVSSUZJQ0FUSU9OIiwiQ1JFQVRFX09ORV9TVEFHRV9TQUxFIiwiQ1JFQVRFX09SREVSIiwiTUFOQUdFX1JFRlVORCIsIkNSRUFURV9TVEFORF9BTE9ORV9SRUZVTkQiXX0sInJlc291cmNlX2FjY2VzcyI6e30sInNjb3BlIjoiIiwiY2xpZW50SWQiOiI0NWU3MWM5MC1iOTVlLTRiYTgtYmVkYy05YjZiOWExMGFiYTUiLCJjbGllbnRIb3N0IjoiMTY3LjYxLjExNi44MSIsInJlYWxtIjoibmkiLCJnaXZlbl9uYW1lIjoiRS1Db20gQWNjb3VudCIsImNsaWVudEFkZHJlc3MiOiIxNjcuNjEuMTE2LjgxIiwiaGllcmFyY2h5UmVmcyI6WyIxMTQ0ZGZkOS1mNTJhLTQ0ZDEtOTA3ZC1jY2QzZjgzYTYyMjIiXX0.hFnwSOU92-MCUWUp4fkEE9FLDYAUBpzwx6LlaWSV49DeZrzzZaWBNBeflN0XLRXcJ0LkbzOP8IBLinG9mwGYPdVq7bC1KT-URtg-zvPVfxsUaA6w-q1qerb2D3YmW9434K1Q5qGrS4StLCE5jBMuVAv5FVZX8uaO91abNxxCfWUFQg1gUEUjudCqeDtzEhN0_BlOQm8bWX5M-1sJiLsVA4YuT7Fh8e0eCDFevQvLKRD6UI5aYHnzJf7RcDy9nXlNfGyJI7cfB-ym3k1TOceGoe38jCh2tZbA4zF3P6Rh27F2CwJfypxQagx0pQPE4f0WLnsWofU9Er13jfi4TJgTYQ\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nConnection: close\r\nHost: api-gateway-uat.ngenius-payments.com\r\nContent-Length: 458\r\n\r\n"
<- "{\"order\":{\"action\":\"SALE\",\"amount\":{\"value\":\"1000\",\"currencyCode\":\"AED\"}},\"payment\":{\"pan\":\"4093191766216474\",\"cvv\":\"123\",\"expiry\":\"2021-09\",\"cardholderName\":\"Longbob Longsen\"},\"billingAddress\":{\"firstName\":null,\"lastName\":null,\"address1\":\"456 My Street\",\"city\":\"Ottawa\",\"countryCode\":\"CA\"},\"emailAddress\":null,\"language\":null,\"merchantOrderReference\":null,\"merchantAttributes\":{\"skipConfirmationPage\":true,\"skip3DS\":true,\"cancelUrl\":null,\"cancelText\":null}}"
-> "HTTP/1.1 201 Created\r\n"
-> "Server: CPWS\r\n"
-> "Content-Length: 1531\r\n"
-> "Location: https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/efda69e2-acf6-473a-b7aa-4dbf9e7d5d28/payments/a1e188fc-064c-4b27-96e8-dbeb563e83b1\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "X-Correlation-Id: 0e867df1e7b777e3b6bf9329f22b7ebf\r\n"
-> "X-Frame-Options: DENY\r\n"
-> "X-XSS-Protection: 1; mode=block\r\n"
-> "Content-Type: application/vnd.ni-payment.v2+json\r\n"
-> "Expires: Wed, 15 Jan 2020 17:52:42 GMT\r\n"
-> "Cache-Control: max-age=0, no-cache, no-store\r\n"
-> "Pragma: no-cache\r\n"
-> "Date: Wed, 15 Jan 2020 17:52:42 GMT\r\n"
-> "Connection: close\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "\r\n"
reading 1531 bytes...
-> "{\"_id\":\"urn:payment:a1e188fc-064c-4b27-96e8-dbeb563e83b1\",\"_links\":{\"self\":{\"href\":\"https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/efda69e2-acf6-473a-b7aa-4dbf9e7d5d28/payments/a1e188fc-064c-4b27-96e8-dbeb563e83b1\"},\"curies\":[{\"name\":\"cnp\",\"href\":\"https://api-gateway.sandbox.ngenius-payments.com/docs/rels/{rel}\",\"templated\":true}]},\"paymentMethod\":{\"expiry\":\"2021-09\",\"cardholderName\":\"Longbob Longsen\",\"name\":\"VISA\",\"pan\":\"409319******6474\",\"cvv\":\"***\"},\"savedCard\":{\"maskedPan\":\"409319******6474\",\"expiry\":\"2021-09\",\"cardholderName\":\"Longbob Longsen\",\"scheme\":\"VISA\",\"cardToken\":\"dG9rZW5pemVkUGFuLy92MS8vU0hPV19"
-> "OT05FLy83MTkxMzkwNDQ3NDYxMjY2\",\"recaptureCsc\":true},\"state\":\"CAPTURED\",\"amount\":{\"currencyCode\":\"AED\",\"value\":1000},\"updateDateTime\":\"2020-01-15T17:52:42.319Z\",\"outletId\":\"e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d\",\"orderReference\":\"efda69e2-acf6-473a-b7aa-4dbf9e7d5d28\",\"authResponse\":{\"authorizationCode\":\"128120\",\"success\":true,\"resultCode\":\"00\",\"resultMessage\":\"Successful approval/completion or that VIP PIN verification is valid\"},\"3ds\":{},\"_embedded\":{\"cnp:capture\":[{\"_links\":{\"self\":{\"href\":\"https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/efda69e2-acf6-473a-b7aa-4dbf9e7d5d28/payments/a1e188fc-064c-4b27-96e8-dbeb563e83b1/captures/6cfee772-fa4f-41e6-8153-e1fb01d02fa1\"}},\"amount\":{\"currencyCode\":\"AED\",\"value\":1000},\"createdTime\":\"2020-01-15T17:52:42.319Z\",\"state\":\"SUCCESS\"}]}}"
read 1531 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    "    opening connection to api-gateway-uat.ngenius-payments.com:443...\n    opened\nstarting SSL for api-gateway-uat.ngenius-payments.com:443...\nSSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384\n<- \"POST /transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/payment/card HTTP/1.1\\r\\nContent-Type: application/vnd.ni-payment.v2+json\\r\\nAccept: application/vnd.ni-payment.v2+json\\r\\nUser-Agent: ActiveMerchant/1.78.0\\r\\nX-Client-Ip: \\r\\nAuthorization: Bearer [FILTERED]\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nConnection: close\\r\\nHost: api-gateway-uat.ngenius-payments.com\\r\\nContent-Length: 458\\r\\n\\r\\n\"\n<- \"{\\\"order\\\":{\\\"action\\\":\\\"SALE\\\",\\\"amount\\\":{\\\"value\\\":\\\"1000\\\",\\\"currencyCode\\\":\\\"AED\\\"}},\\\"payment\\\":{\\\"pan\\\":\\\"[FILTERED]\\\",\\\"cvv\\\":\\\"[FILTERED]\\\",\\\"expiry\\\":\\\"2021-09\\\",\\\"cardholderName\\\":\\\"Longbob Longsen\\\"},\\\"billingAddress\\\":{\\\"firstName\\\":null,\\\"lastName\\\":null,\\\"address1\\\":\\\"456 My Street\\\",\\\"city\\\":\\\"Ottawa\\\",\\\"countryCode\\\":\\\"CA\\\"},\\\"emailAddress\\\":null,\\\"language\\\":null,\\\"merchantOrderReference\\\":null,\\\"merchantAttributes\\\":{\\\"skipConfirmationPage\\\":true,\\\"skip3DS\\\":true,\\\"cancelUrl\\\":null,\\\"cancelText\\\":null}}\"\n-> \"HTTP/1.1 201 Created\\r\\n\"\n-> \"Server: CPWS\\r\\n\"\n-> \"Content-Length: 1531\\r\\n\"\n-> \"Location: https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/efda69e2-acf6-473a-b7aa-4dbf9e7d5d28/payments/a1e188fc-064c-4b27-96e8-dbeb563e83b1\\r\\n\"\n-> \"X-Content-Type-Options: nosniff\\r\\n\"\n-> \"X-Correlation-Id: 0e867df1e7b777e3b6bf9329f22b7ebf\\r\\n\"\n-> \"X-Frame-Options: DENY\\r\\n\"\n-> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n-> \"Content-Type: application/vnd.ni-payment.v2+json\\r\\n\"\n-> \"Expires: Wed, 15 Jan 2020 17:52:42 GMT\\r\\n\"\n-> \"Cache-Control: max-age=0, no-cache, no-store\\r\\n\"\n-> \"Pragma: no-cache\\r\\n\"\n-> \"Date: Wed, 15 Jan 2020 17:52:42 GMT\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Strict-Transport-Security: max-age=15768000\\r\\n\"\n-> \"\\r\\n\"\nreading 1531 bytes...\n-> \"{\\\"_id\\\":\\\"urn:payment:a1e188fc-064c-4b27-96e8-dbeb563e83b1\\\",\\\"_links\\\":{\\\"self\\\":{\\\"href\\\":\\\"https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/efda69e2-acf6-473a-b7aa-4dbf9e7d5d28/payments/a1e188fc-064c-4b27-96e8-dbeb563e83b1\\\"},\\\"curies\\\":[{\\\"name\\\":\\\"cnp\\\",\\\"href\\\":\\\"https://api-gateway.sandbox.ngenius-payments.com/docs/rels/{rel}\\\",\\\"templated\\\":true}]},\\\"paymentMethod\\\":{\\\"expiry\\\":\\\"2021-09\\\",\\\"cardholderName\\\":\\\"Longbob Longsen\\\",\\\"name\\\":\\\"VISA\\\",\\\"pan\\\":\\\"[FILTERED]******6474\\\",\\\"cvv\\\":\\\"***\\\"},\\\"savedCard\\\":{\\\"maskedPan\\\":\\\"409319******6474\\\",\\\"expiry\\\":\\\"2021-09\\\",\\\"cardholderName\\\":\\\"Longbob Longsen\\\",\\\"scheme\\\":\\\"VISA\\\",\\\"cardToken\\\":\\\"dG9rZW5pemVkUGFuLy92MS8vU0hPV19\"\n-> \"OT05FLy83MTkxMzkwNDQ3NDYxMjY2\\\",\\\"recaptureCsc\\\":true},\\\"state\\\":\\\"CAPTURED\\\",\\\"amount\\\":{\\\"currencyCode\\\":\\\"AED\\\",\\\"value\\\":1000},\\\"updateDateTime\\\":\\\"2020-01-15T17:52:42.319Z\\\",\\\"outletId\\\":\\\"e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d\\\",\\\"orderReference\\\":\\\"efda69e2-acf6-473a-b7aa-4dbf9e7d5d28\\\",\\\"authResponse\\\":{\\\"authorizationCode\\\":\\\"128120\\\",\\\"success\\\":true,\\\"resultCode\\\":\\\"00\\\",\\\"resultMessage\\\":\\\"Successful approval/completion or that VIP PIN verification is valid\\\"},\\\"3ds\\\":{},\\\"_embedded\\\":{\\\"cnp:capture\\\":[{\\\"_links\\\":{\\\"self\\\":{\\\"href\\\":\\\"https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/efda69e2-acf6-473a-b7aa-4dbf9e7d5d28/payments/a1e188fc-064c-4b27-96e8-dbeb563e83b1/captures/6cfee772-fa4f-41e6-8153-e1fb01d02fa1\\\"}},\\\"amount\\\":{\\\"currencyCode\\\":\\\"AED\\\",\\\"value\\\":1000},\\\"createdTime\\\":\\\"2020-01-15T17:52:42.319Z\\\",\\\"state\\\":\\\"SUCCESS\\\"}]}}\"\nread 1531 bytes\nConn close\n"
  end

  def successful_purchase_response
    {
      "_id":"urn:payment:34b04bd0-372e-4889-9855-75cdc5763a6d",
      "_links":{
        "self":{
          "href":"https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/7f5c4b85-80af-4b23-8571-7884d5df54f8/payments/34b04bd0-372e-4889-9855-75cdc5763a6d"
        },
        "curies":[
          {
            "name":"cnp",
            "href":"https://api-gateway.sandbox.ngenius-payments.com/docs/rels/{rel}",
            "templated":true
          }
        ]
      },
      "paymentMethod":{
        "expiry":"2021-09",
        "cardholderName":"Longbob Longsen",
        "name":"VISA",
        "pan":"409319******6474",
        "cvv":"***"
      },
      "savedCard":{
        "maskedPan":"409319******6474",
        "expiry":"2021-09",
        "cardholderName":"Longbob Longsen",
        "scheme":"VISA",
        "cardToken":"dG9rZW5pemVkUGFuLy92MS8vU0hPV19OT05FLy83MTkxMzkwNDQ3NDYxMjY2",
        "recaptureCsc":true
      },
      "state":"CAPTURED",
      "amount":{
        "currencyCode":"AED",
        "value":1000
      },
      "updateDateTime":"2020-01-15T17:10:42.242Z",
      "outletId":"e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d",
      "orderReference":"7f5c4b85-80af-4b23-8571-7884d5df54f8",
      "authResponse":{
        "authorizationCode":"128120",
        "success":true,
        "resultCode":"00",
        "resultMessage":"Successful approval/completion or that VIP PIN verification is valid"
      },
      "3ds":{},
      "_embedded":{
        "cnp:capture":[
          {
            "_links":{
              "self":{
                "href":"https://api-gateway.sandbox.ngenius-payments.com/transactions/outlets/e209b88c-9fb6-4be8-ab4b-e4b977ad0e0d/orders/7f5c4b85-80af-4b23-8571-7884d5df54f8/payments/34b04bd0-372e-4889-9855-75cdc5763a6d/captures/e091b87e-396b-4ec1-8ee6-7c3c5fb70b97"
                }
              },
            "amount":{"currencyCode":"AED","value":1000},
            "createdTime":"2020-01-15T17:10:42.242Z",
            "state":"SUCCESS"
          }
        ]
      }
    }.to_json
  end
end
