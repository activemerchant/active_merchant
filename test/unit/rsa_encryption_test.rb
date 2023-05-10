require 'test_helper'

class RsaEncryptionTest < Test::Unit::TestCase
  def test_ruby_encrypt_decrypt
    public_key = Base64.decode64('MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0iEqfpLmo987S7Hhsd2blxqGYDf5YPphgE5YtU2mINfsObPRi3h5crxtjh8ADHASljOc9ajKLPJpen9PB+qqd7jZgfIf1+CI/oRKPW1ny71z4KO4PNXKqTIwP/cFvhQXzh6+PSPRHBlKIzPbu84fK7opurqNcndx2OLQiFHbpQMrUz++uEvJ5N99kMGLX6WUnDL8QEwo7t/zer/kxlL1ULLrn6vycBhhrOpO8FiLpL2jp+oixGj5AkqHcHihUGfqm0fAV5lgiwAZNW3X72qJFbp7ot5etcmhScwxzw0irPiMq7G5/NFC7JKPNORwtUBUV6V1acW98JAGxngDe7zksQIDAQAB')
    encrypted = asymetrical_encrypt(public_key, 'Hello World')
    `echo #{encrypted} | pbcopy`

    assert_equal 'Hello World', private_key.private_decrypt(Base64.strict_decode64(encrypted), OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
  end

  def test_golang_decrypt
    go_encrypted = 'KMjNRKp/XVV1l+zNvnErK7y0Yj0Rn1PNlG3qYbEf2QGJyKgK91dvmOD8zxiIe/it68gLdj2Tc0sNsJNvg3k0zFo7rUNy6CHgJfW9Zsn9NccImydBkR17oOVG51Hb62d5ezkK3vKVV2PPnseuf4aGuujvj2AYr3/czkGMlYJiBJbcUYeF63Mgygp7w6bIGB/k3EqgOxFEx2HTk++5S6kJ6hfWLj2Li4NNTiZm33oP+zWustJPGVpGNizT4aT/pAYqCPbLRR11yx46vBe1lbQzXfva+xE4U3VHJmVIB3kcUViuBfS9aOylbfk+wPetUOAPh3v2+yu65jFiKhw8eGWTpQ=='

    assert_equal 'Hello World', private_key.private_decrypt(Base64.strict_decode64(go_encrypted), OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
  end

  def test_js_decrypt
    js_encrypted = 'gBBTePH+We/Fbd4hhOImCWmJmeRnHB8sohuwjJrx+szDJpisorAJg0PW6Zog4pTqnupgx1qvtquv92BtQpnSn4wKDcuy86Nsg/fmLOS2BvDxOmhMEFw35+t85+UgSK8S3P2r+IiHLtQsldbVbVYu5fr2qjsm1xCofLFERXoPC4tBeKiVOCHWPSZq6n/8MC8BqxrKnvxDxskc8U+/bqMvH7p51tB/DALKoqGsU3q0yWvKLwqlWpBwONfbm99xrPZ0TCKNkCU1f0MgCBIYraW3mygTqw9DkEdU8XZyLkoE8OlxHF/DCl12LX3U5Im509F87GI9yrMmnG1hQ7kTLVEOrA=='

    assert_equal 'Hello World', private_key.private_decrypt(Base64.strict_decode64(js_encrypted), OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
  end

  private

  def asymetrical_encrypt(pub_key, source_string)
    public_key = OpenSSL::PKey::RSA.new(pub_key)
    encrypted = public_key.public_encrypt(source_string, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
    Base64.strict_encode64(encrypted)
  end

  def private_key
    @private_key ||= OpenSSL::PKey::RSA.new(File.read('private_pkcs8.pem'), '')
  end
end
