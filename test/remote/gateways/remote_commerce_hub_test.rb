require 'test_helper'

class RemoteCommerceHubTest < Test::Unit::TestCase
  def setup
    @gateway = CommerceHubGateway.new(fixtures(:commerce_hub))

    @amount = 1204
    @credit_card = credit_card('4005550000000019', month: '02', year: '2035', verification_value: '123')
    @declined_card = credit_card('4000300011112220', month: '02', year: '2035', verification_value: '123')
    @options = {}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_billing_and_shipping
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ billing_address: address, shipping_address: address }))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_stored_credential_framework
    stored_credential_options = {
      initial_transaction: true,
      reason_type: 'recurring',
      initiator: 'merchant'
    }
    first_response = @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_options }))
    assert_success first_response

    ntxid = first_response.params['transactionDetails']['retrievalReferenceNumber']
    stored_credential_options = {
      initial_transaction: false,
      reason_type: 'recurring',
      initiator: 'merchant',
      network_transaction_id: ntxid
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_options }))
    assert_success response
  end

  def test_successful_purchase_with_apple_pay
    apple_pay_config = {
      data: 'hbreWcQg980mUoUCfuCoripnHO210lvtizOFLV6PTw1DjooSwik778bH/qgK2pKelDTiiC8eXeiSwSIfrTPp6tq9x8Xo2H0KYAHCjLaJtoDdnjXm8QtC3m8MlcKAyYKp4hOW6tcPmy5rKVCKr1RFCDwjWd9zfVmp/au8hzZQtTYvnlje9t36xNy057eKmA1Bl1r9MFPxicTudVesSYMoAPS4IS+IlYiZzCPHzSLYLvFNiLFzP77qq7B6HSZ3dAZm244v8ep9EQdZVb1xzYdr6U+F5n1W+prS/fnL4+PVdiJK1Gn2qhiveyQX1XopLEQSbMDaW0wYhfDP9XM/+EDMLaXIKRiCtFry9nkbQZDjr2ti91KOAvzQf7XFbV+O8i60BSlI4/QRmLdKHmk/m0rDgQAoYLgUZ5xjKzXpJR9iW6RWuNYyaf9XdD8s2eB9aBQ=',
      application_data_hash: '94ee059335e587e501cc4bf90613e0814f00a7b08bc7c648fd865a2af6a22cc2',
      ephemeral_public_key: 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEvR+anQg6pElOsCnC3HIeNoEs2XMHQwxuy9plV1MfRRtIiHnQ6MyOS+1FQ7WZR2bVAnHFhPFaM9RYe7/bynvVvg==',
      public_key_hash: 'KRsyW0NauLpN8OwKr+yeu4jl6APbgW05/TYo5eGW0bQ=',
      transaction_id: '31323334353637',
      signature: 'MIAGCSqGSIb3DQEHAqCAMIACAQExDzANBglghkgBZQMEAgEFADCABgkqhkiG9w0BBwEAAKCAMIIB0zCCAXkCAQEwCQYHKoZIzj0EATB2MQswCQYDVQQGEwJVUzELMAkGA1UECAwCTkoxFDASBgNVBAcMC0plcnNleSBDaXR5MRMwEQYDVQQKDApGaXJzdCBEYXRhMRIwEAYDVQQLDAlGaXJzdCBBUEkxGzAZBgNVBAMMEmQxZHZ0bDEwMDAuMWRjLmNvbTAeFw0xNTA3MjMxNjQxMDNaFw0xOTA3MjIxNjQxMDNaMHYxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJOSjEUMBIGA1UEBwwLSmVyc2V5IENpdHkxEzARBgNVBAoMCkZpcnN0IERhdGExEjAQBgNVBAsMCUZpcnN0IEFQSTEbMBkGA1UEAwwSZDFkdnRsMTAwMC4xZGMuY29tMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErnHhPM18HFbOomJMUiLiPL7nrJuWvfPy0Gg3xsX3m8q0oWhTs1QcQDTT+TR3yh4sDRPqXnsTUwcvbrCOzdUEeTAJBgcqhkjOPQQBA0kAMEYCIQDrC1z2JTx1jZPvllpnkxPEzBGk9BhTCkEB58j/Cv+sXQIhAKGongoz++3tJroo1GxnwvzK/Qmc4P1K2lHoh9biZeNhAAAxggFSMIIBTgIBATB7MHYxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJOSjEUMBIGA1UEBwwLSmVyc2V5IENpdHkxEzARBgNVBAoMCkZpcnN0IERhdGExEjAQBgNVBAsMCUZpcnN0IEFQSTEbMBkGA1UEAwwSZDFkdnRsMTAwMC4xZGMuY29tAgEBMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTkwNjA3MTg0MTIxWjAvBgkqhkiG9w0BCQQxIgQg0PLaZU4YWZqtP9t/ygv9XIS/5ngU6FlGjpvyK6VFXVMwCgYIKoZIzj0EAwIERjBEAiBTNmQEPyc3aMm4Mwa0riD3dNdSc9aAhslj65Us8b3aKwIgNSc/y+CWpsr8qDln0fZK6ZD/LWPMxofQedlPy7Q6gY8AAAAAAAA=',
      version: 'EC_v1',
      application_data: 'VEVTVA==',
      merchant_id: 'merchant.com.fapi.tcoe.applepay',
      merchant_private_key: 'MHcCAQEE234234234opsmasdsalsamdsad/asdsad/asdasd/asdAwEHoUQDQgAaslkdsad8asjdnlkm23leu9jclaskdas/masr4+/as34+4fh/sf64g/nX35fs5w=='
    }
    apple_pay = network_tokenization_credit_card('4242424242424242', payment_cryptogram: '111111111100cryptogram', brand: 'apple_pay')
    assert response = @gateway.purchase(@amount, apple_pay, @options.merge({ apple_pay: apple_pay_config }))
    assert_success response
  end

  def test_successful_purchase_with_google_pay
    google_pay_config = {
      encrypted_message: 'NZF5Vs2YaI/t25L/1+dp6tuUOvra9pszs2antqcbHJbkjMMXZSR7innTFJxNR5DNnf4GheWIso8n8MA1q1zqWCU8MaK9bnNcHxvROpvfsU3SCCjkfG2k2M4/RYMjs+lxYW/nEtIIKVVOkdjAj4pI/Wth8xQXphn7hDNiyp9tIydmlPZVnzkXI6mVbpHbbkaCCD4TNPhFBDtx0VafqRjbb2Wt3EDazTx3dHdd+qVX5Xj8/BPb1cmwHWvrDw/dQRk/E0TsP+erLjhLaZ8l2EycxeUEZYqSX5w77S8vd3sw8WXuOCMsU8sx0Bs5IY7hohq67qNDxckP1fcBD4OYdGP6bumJR0J6pJxD5iRh5lFSjN6zNLRI77ylxWL6DwHoe/pPdCc0n6cV0Nt0RJMLjerr12BLuhv4bPQ3QB6jxnbt8JK/EndgIG8xpFyNkKlRUyxAKM22/ZSy45d6qtZIKLXRqDTr9JMk8uJ53QRZtQx8k9KkRZGC+GM2sD+Z75fxc0Yye7l6H0D8p5z1iEzWnYHxd0pmY/cOYEJxnOOdD573QmE6ikFcyaAw3XnCyul/EA==',
      ephemeral_public_key: 'BAhnPIWrCXWv/45GFK0mNAvN9w+NFBs3tQji0wTUS2+hiFKsZujG5wRd4JXGmxhG+k3bglYk544ILBNdDpsAh+o=',
      tag: 'liBzKfGcO+FclHg7XuqRJxR/8EJShRp9/APab0Sho08=',
      signature: 'MEUCIFWTRWUZAOM5nfJC79FtJm56olnbwG4H5uWWxAUWAquiAiEA24j/BcOroeISsdJzYsyoVi8wzu4tnmKw+jdsGfuvPko=',
      version: 'ECv2',
      merchant_id: '676174657761793A666972737464617461',
      merchant_private_key: 'DCEDF9AF72707BFD9C5231ECB9EAD040F3B4BA2AB608579736E37FDBA8884175566BDA410997B2575EA7E76AC54BBDB99DD0F74DD0A648BC0F6A2F06909E79A0F15D779F1A80CFC1EC9612476204C43A',
      signing_verification_key: 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEIsFro6K+IUxRr4yFTOTO+kFCCEvHo7B9IOMLxah6c977oFzX/beObH4a9OfosMHmft3JJZ6B3xpjIb8kduK4/A=='
    }
    google_pay = network_tokenization_credit_card('4242424242424242', payment_cryptogram: '111111111100cryptogram', brand: 'google_pay')
    assert response = @gateway.purchase(@amount, google_pay, @options.merge({ google_pay: google_pay_config }))
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Unable to assign card to brand: Invalid.', response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Unable to assign card to brand: Invalid.', response.message
  end

  def test_successful_authorize_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.void(response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_void
    response = @gateway.void('123', @options)
    assert_failure response
    assert_equal 'Referenced transaction is invalid or not found', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_and_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.refund(nil, response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_and_partial_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.refund(@amount - 1, response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, '123', @options)
    assert_failure response
    assert_equal 'Referenced transaction is invalid or not found', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'TOKENIZE', response.message
  end

  def test_successful_store_with_purchase
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'TOKENIZE', response.message

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
    assert_scrubbed(@gateway.options[:api_secret], transcript)
  end
end
