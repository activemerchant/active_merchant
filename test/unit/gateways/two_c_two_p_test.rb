require 'test_helper'

class TwoCTwoPGatewayTest < Test::Unit::TestCase
  def setup
    @gateway = TwoCTwoPGateway.new(merchant_id: 'login', secret_key: 'password')
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

    assert_equal '631496', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Card Number.', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_purchase_response
    <<-eos
    PFBheW1lbnRSZXNwb25zZT48dmVyc2lvbj45Ljk8L3ZlcnNpb24+PHBheWxvYWQ+UEZCaGVXMWxiblJTWlhOd2IyNXpaVDQ4ZEdsdFpWTjBZVzF3UGpJM01EZ3lNREU1TXpNd056d3ZkR2x0WlZOMFlXMXdQanh0WlhKamFHRnVkRWxFUGtwVU1ERThMMjFsY21Ob1lXNTBTVVErUEhKbGMzQkRiMlJsUGpBd1BDOXlaWE53UTI5a1pUNDhjR0Z1UGpReU5ESTBNbGhZV0ZoWVdEUXlOREk4TDNCaGJqNDhZVzEwUGpBd01EQXdNREF3TURFd01Ed3ZZVzEwUGp4MWJtbHhkV1ZVY21GdWMyRmpkR2x2YmtOdlpHVStaR1F3WTJZeU5UUXdaand2ZFc1cGNYVmxWSEpoYm5OaFkzUnBiMjVEYjJSbFBqeDBjbUZ1VW1WbVBqTXlNREEyTXpJOEwzUnlZVzVTWldZK1BHRndjSEp2ZG1Gc1EyOWtaVDQyTXpFME9UWThMMkZ3Y0hKdmRtRnNRMjlrWlQ0OGNtVm1UblZ0WW1WeVBtUmtNR05tTWpVME1HWThMM0psWms1MWJXSmxjajQ4WldOcFBqQTNQQzlsWTJrK1BHUmhkR1ZVYVcxbFBqSTNNRGd5TURJd016TXdOend2WkdGMFpWUnBiV1UrUEhOMFlYUjFjejVCUEM5emRHRjBkWE0rUEdaaGFXeFNaV0Z6YjI0K1FYQndjbTkyWldROEwyWmhhV3hTWldGemIyNCtQSFZ6WlhKRVpXWnBibVZrTVQ0OEwzVnpaWEpFWldacGJtVmtNVDQ4ZFhObGNrUmxabWx1WldReVBqd3ZkWE5sY2tSbFptbHVaV1F5UGp4MWMyVnlSR1ZtYVc1bFpETStQQzkxYzJWeVJHVm1hVzVsWkRNK1BIVnpaWEpFWldacGJtVmtORDQ4TDNWelpYSkVaV1pwYm1Wa05ENDhkWE5sY2tSbFptbHVaV1ExUGp3dmRYTmxja1JsWm1sdVpXUTFQanhwY0hCUVpYSnBiMlErUEM5cGNIQlFaWEpwYjJRK1BHbHdjRWx1ZEdWeVpYTjBWSGx3WlQ0OEwybHdjRWx1ZEdWeVpYTjBWSGx3WlQ0OGFYQndTVzUwWlhKbGMzUlNZWFJsUGp3dmFYQndTVzUwWlhKbGMzUlNZWFJsUGp4cGNIQk5aWEpqYUdGdWRFRmljMjl5WWxKaGRHVStQQzlwY0hCTlpYSmphR0Z1ZEVGaWMyOXlZbEpoZEdVK1BIQmhhV1JEYUdGdWJtVnNQand2Y0dGcFpFTm9ZVzV1Wld3K1BIQmhhV1JCWjJWdWRENDhMM0JoYVdSQloyVnVkRDQ4Y0dGNWJXVnVkRU5vWVc1dVpXdytQQzl3WVhsdFpXNTBRMmhoYm01bGJENDhZbUZqYTJWdVpFbHVkbTlwWTJVK016QTRNak0zTUR3dlltRmphMlZ1WkVsdWRtOXBZMlUrUEdsemMzVmxja052ZFc1MGNuaytWVk04TDJsemMzVmxja052ZFc1MGNuaytQR2x6YzNWbGNrTnZkVzUwY25sQk16NVZVMEU4TDJsemMzVmxja052ZFc1MGNubEJNejQ4WW1GdWEwNWhiV1UrU2xCTlQxSkhRVTRnUTBoQlUwVWdRa0ZPU3lCT1FUd3ZZbUZ1YTA1aGJXVStQR05oY21SVWVYQmxQa05TUlVSSlZEd3ZZMkZ5WkZSNWNHVStQSEJ5YjJObGMzTkNlVDVXU1R3dmNISnZZMlZ6YzBKNVBqeHdZWGx0Wlc1MFUyTm9aVzFsUGxaSlBDOXdZWGx0Wlc1MFUyTm9aVzFsUGp4eVlYUmxVWFZ2ZEdWSlJENDhMM0poZEdWUmRXOTBaVWxFUGp4dmNtbG5hVzVoYkVGdGIzVnVkRDQ4TDI5eWFXZHBibUZzUVcxdmRXNTBQanhtZUZKaGRHVStNQzR3UEM5bWVGSmhkR1UrUEdOMWNuSmxibU41UTI5a1pUNDNNREk4TDJOMWNuSmxibU41UTI5a1pUNDhMMUJoZVcxbGJuUlNaWE53YjI1elpUND08L3BheWxvYWQ+PHNpZ25hdHVyZT45MDhDMzE4NjlBMERCQTVFMTY0N0E5REVEREUxRkVGRUM0QjNGODdDMDU5QzE0RDJBRjcwQkY0QjIzMDk1RkUxPC9zaWduYXR1cmU+PC9QYXltZW50UmVzcG9uc2U+
    eos
  end

  def failed_purchase_response
    <<-eos
    PFBheW1lbnRSZXNwb25zZT48dmVyc2lvbj45Ljk8L3ZlcnNpb24+PHBheWxvYWQ+UEZCaGVXMWxiblJTWlhOd2IyNXpaVDQ4ZEdsdFpWTjBZVzF3UGpJM01EZ3lNREU1TXpVMU9Ud3ZkR2x0WlZOMFlXMXdQanh0WlhKamFHRnVkRWxFUGtwVU1ERThMMjFsY21Ob1lXNTBTVVErUEhKbGMzQkRiMlJsUGprNVBDOXlaWE53UTI5a1pUNDhjR0Z1UGpReE1URXhNVmhZV0ZoWU1URXhNVHd2Y0dGdVBqeGhiWFErTURBd01EQXdNREF3TVRBd1BDOWhiWFErUEhWdWFYRjFaVlJ5WVc1ellXTjBhVzl1UTI5a1pUNHhZbVV6WXpVNU9EUXpQQzkxYm1seGRXVlVjbUZ1YzJGamRHbHZia052WkdVK1BIUnlZVzVTWldZK1BDOTBjbUZ1VW1WbVBqeGhjSEJ5YjNaaGJFTnZaR1UrUEM5aGNIQnliM1poYkVOdlpHVStQSEpsWms1MWJXSmxjajQ4TDNKbFprNTFiV0psY2o0OFpXTnBQand2WldOcFBqeGtZWFJsVkdsdFpUNHlOekE0TWpBeU1ETTFOVGs4TDJSaGRHVlVhVzFsUGp4emRHRjBkWE0rUmp3dmMzUmhkSFZ6UGp4bVlXbHNVbVZoYzI5dVBrbHVkbUZzYVdRZ1EyRnlaQ0JPZFcxaVpYSXVQQzltWVdsc1VtVmhjMjl1UGp4MWMyVnlSR1ZtYVc1bFpERStQQzkxYzJWeVJHVm1hVzVsWkRFK1BIVnpaWEpFWldacGJtVmtNajQ4TDNWelpYSkVaV1pwYm1Wa01qNDhkWE5sY2tSbFptbHVaV1F6UGp3dmRYTmxja1JsWm1sdVpXUXpQangxYzJWeVJHVm1hVzVsWkRRK1BDOTFjMlZ5UkdWbWFXNWxaRFErUEhWelpYSkVaV1pwYm1Wa05UNDhMM1Z6WlhKRVpXWnBibVZrTlQ0OGFYQndVR1Z5YVc5a1Bqd3ZhWEJ3VUdWeWFXOWtQanhwY0hCSmJuUmxjbVZ6ZEZSNWNHVStQQzlwY0hCSmJuUmxjbVZ6ZEZSNWNHVStQR2x3Y0VsdWRHVnlaWE4wVW1GMFpUNDhMMmx3Y0VsdWRHVnlaWE4wVW1GMFpUNDhhWEJ3VFdWeVkyaGhiblJCWW5OdmNtSlNZWFJsUGp3dmFYQndUV1Z5WTJoaGJuUkJZbk52Y21KU1lYUmxQanh3WVdsa1EyaGhibTVsYkQ0OEwzQmhhV1JEYUdGdWJtVnNQanh3WVdsa1FXZGxiblErUEM5d1lXbGtRV2RsYm5RK1BIQmhlVzFsYm5SRGFHRnVibVZzUGp3dmNHRjViV1Z1ZEVOb1lXNXVaV3crUEdKaFkydGxibVJKYm5admFXTmxQand2WW1GamEyVnVaRWx1ZG05cFkyVStQR2x6YzNWbGNrTnZkVzUwY25rK1BDOXBjM04xWlhKRGIzVnVkSEo1UGp4cGMzTjFaWEpEYjNWdWRISjVRVE0rUEM5cGMzTjFaWEpEYjNWdWRISjVRVE0rUEdKaGJtdE9ZVzFsUGp3dlltRnVhMDVoYldVK1BHTmhjbVJVZVhCbFBqd3ZZMkZ5WkZSNWNHVStQSEJ5YjJObGMzTkNlVDVXU1R3dmNISnZZMlZ6YzBKNVBqeHdZWGx0Wlc1MFUyTm9aVzFsUGxaSlBDOXdZWGx0Wlc1MFUyTm9aVzFsUGp4eVlYUmxVWFZ2ZEdWSlJENDhMM0poZEdWUmRXOTBaVWxFUGp4dmNtbG5hVzVoYkVGdGIzVnVkRDQ4TDI5eWFXZHBibUZzUVcxdmRXNTBQanhtZUZKaGRHVStQQzltZUZKaGRHVStQR04xY25KbGJtTjVRMjlrWlQ0OEwyTjFjbkpsYm1ONVEyOWtaVDQ4TDFCaGVXMWxiblJTWlhOd2IyNXpaVDQ9PC9wYXlsb2FkPjxzaWduYXR1cmU+RjNGMjMyOTY0NEQ5REJGQTE2QTZENDlBQzYzREY1NTgzQ0NGQTJCRDg2MEIwREYzREI5OUJCRkVGQjRGMUU2NDwvc2lnbmF0dXJlPjwvUGF5bWVudFJlc3BvbnNlPg==
    eos
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to demo2.2c2p.com:443...
      opened
      starting SSL for demo2.2c2p.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /2C2PFrontEnd/SecurePayment/Payment.aspx HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: demo2.2c2p.com\r\nContent-Length: 1199\r\n\r\n"
      <- "paymentRequest=PFBheW1lbnRSZXF1ZXN0Pjx2ZXJzaW9uPjkuOTwvdmVyc2lvbj48cGF5bG9hZD5QRkJoZVcxbGJuUlNaWEYxWlhOMFBqeGhiWFErTURBd01EQXdNREF3TVRBd1BDOWhiWFErUEdOMWNuSmxibU41UTI5a1pUNDNNREk4TDJOMWNuSmxibU41UTI5a1pUNDhjR0Z1UTI5MWJuUnllVDVUUnp3dmNHRnVRMjkxYm5SeWVUNDhZMkZ5WkdodmJHUmxjazVoYldVK1RHOXVaMkp2WWlCTWIyNW5jMlZ1UEM5allYSmthRzlzWkdWeVRtRnRaVDQ4Wlc1alEyRnlaRVJoZEdFK01EQmhZMFpsTUhJeVlsWkRRMkl2TlZkRWRqbElibWxvZW5SUlEyVXhRMHBGZW5oRlkySlNlV1UzUTJGTFNXUnBhbFZ6TVdVeFZGZEtkWFJSU2tWdFdHVkxibEJsTkV0UVEwSjRWVmxXUTJWUE1sTjBlWHBuVTJKTGRYTllZa04xV0VOdFpXczNla1l6Tm5SV1dXWXpkWGw2TVRkVmRXNTZkbEJXZVVWQlFXMXBaMGhJUjJsNFVUWmxPRVpqYzA5NlRIa3dhVmhoU1VkaGEzYzBPRWd6VTI4MU5WbGxNemw0TXpBd2RrSlJRVDFWTWtaelpFZFdhMWd4T0VjeWEyOXBaMWhsVEU1NVMyRnBNbGxWVlhKRlJEazRObWw1ZUVFMFVsSmtOV1p6ZEVOU1dsbGhPRlJOY25GeWRIbFFVMHRqUEM5bGJtTkRZWEprUkdGMFlUNDhiV1Z5WTJoaGJuUkpSRDVLVkRBeFBDOXRaWEpqYUdGdWRFbEVQangxYm1seGRXVlVjbUZ1YzJGamRHbHZia052WkdVK056VTNNRGt4TjJJMk1Ed3ZkVzVwY1hWbFZISmhibk5oWTNScGIyNURiMlJsUGp4a1pYTmpQbE4wYjNKbElGQjFjbU5vWVhObFBDOWtaWE5qUGp3dlVHRjViV1Z1ZEZKbGNYVmxjM1ErPC9wYXlsb2FkPjxzaWduYXR1cmU%2BQkU5MjYxQzBDOTU5OTQwMDREODJCNUQwRUI1QjMwRDdBMjUzRTc5NzQwNzhBNEREQjBFQjlDNjUwQjA4NUZCRTwvc2lnbmF0dXJlPjwvUGF5bWVudFJlcXVlc3Q%2B"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 03 Sep 2020 19:14:34 GMT\r\n"
      -> "Content-Type: text/html; charset=utf-8\r\n"
      -> "Content-Length: 2013\r\n"
      -> "Connection: close\r\n"
      -> "Cache-Control: private\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Server: Microsoft-IIS/10.0\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "\r\n"
      reading 2013 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\xED\xBD\a`\x1CI\x96%&/m\xCA{\x7FJ\xF5J\xD7\xE0t\xA1\b\x80`\x13$\xD8\x90@\x10\xEC\xC1\x88\xCD\xE6\x92\xEC\x1DiG#)\xAB*\x81\xCAeVe]f\x16@\xCC\xED\x9D\xBC\xF7\xDE{\xEF\xBD\xF7\xDE{\xEF\xBD\xF7\xBA;\x9DN'\xF7\xDF\xFF?\\fd\x01l\xF6\xCEJ\xDA\xC9\x9E!\x80\xAA\xC8\x1F?~|\x1F?\"^>{2\xCF\xBF\xBB[N\x96\xAF^\xFF\xD4\xEF\xFD\xE2j\xB2w\xFF\a?\xF5f\xFF`\xB6\xF8\xC9\xEB\xE9^y9\xF9\xE9\xFD\xFB\xCF\x7F\xFA\xED\xC1\xF3{?UN\x97/V\x93\xBD\xFDO^~\e\xEF\xBC\xBB\xFC}\xBE\xFB\x13\x9F|u\xFAS'\xD9\xE7?\xF9{\x7F\xF1\xDDw\xC5\xA4\xFC\xCE\x9B\xEF\x96\xF3/g{g\xD7/~\xEFU\xF6\x93O\x7Fb\xFF\xA7Ng\xCD\xEC\xD9\xEA\xBBo~\xFA\xC9O\xFD\xE4\x0F\x9E\xDD\xFB\xEA\xF3\xD5\x93/NwO\xB3{\xE5\x8BW\xA7\xCF\xEE\xBF\xF9\xC9W\xAF\xF2\xB7\xF7Og\xF7~\xEA\xED\xAB\xBDw;\xDF-\x7F\xEA\xCB/\x9E\x95\xBF\xF7\x17\xBF\xF7\xEC'\xB2\xE5\x9C\xFE\x9E\xFF^\xD9\xE2\xD9\xB7_-\x7F\xF2\xED\xAB\xEF\xBE{\xF6\xD5\xE7\xED\xD5O~\xB5{\xFA\xEA\xCD\xFC\x8B/~\xFAY\xF3\xFB\xEC\xED~9\xD9-\x7F\xEF\x17o\x9E\xBC\xF9\xC9\x9F<\xAD\xBF:\x9D\xFF^\x93\xCF\xBF\xF8\xC1O\xBC}U|Q~\xA7A\x7F\xB3\xDD'O\xBF\xFC\xBD\xCB\xEC\xBB\xA7\xF7\xEF}\xF5\xE6\xEC~\xB6\xBB\xFA\xEA\xC5\xD3\xF9O\xBF\xDA\xF9\xA9]\xFA\xFEU\xFE\xD5\xFD\xD3\xD7o\x9E\xBC\x98|>\xFF\xA9\x9F\xDC\xF9\xA9\xEA\xBB?9;\xFD\xEA\xF7.\xBF|u\xFAv\xFF\xCD\xD3\x174\xBE\xEF\xFC\"jO\xF8\x9F^Q\xFB'\xB3\x9D\xDD\xD3\x9F\xF8\xBDg\xC0\xFF\xDE\x9B\xAF^=\xC3\xDF\x84\xBF\xF9~\xFF\x8B\xEF~\xA7\x9D|{\xFE\xF6'w\x7F\xEA'\t\xBF\xCFg\xDF\xFD\xE2\xFA\xD5b\x85\xF1\xED\xFD>\x8B\xF6\xCBY\xB9\xFA\xF6O\xBEn\xBF\xCC\xCB\xAF~@\xEF\xD7\xF9\xE9\xFE\xF5\xEB7\xDFy\xF1\xEA\xDB\xB3\xBD\x9Fz6\xDD\x9D~\xFE\xE2\xF7\xF9\xC9\xC5\xBB\xEF\xBE>]U\xBF\xCF\xE2\xFE\x97\xD9\xB3\xB7?\xF8j\xF9\xA4\xF8\xE2\xA7\x7F\xF2\xF4\xF7\xF9\xE9\xEF\xBC\x9E<{\xF2\x8B\xF2\xA7O~z\xF2\xD5O\xED\xFE\xE4ww\xBF;\xF9\xC9'\xBF\xE8\xCD\xEF]\xBE\xC8J\xA6g\xFD\xE5\xE9\x15\xB5/\t\x9F\x9F\xA4\xF9\x98\xFD\xD4\xEF\xB5\xFB\x84\xE87\xFBi\x82\xB7\xF7S\x9F\xEF~>\xDD=\xBD\xFE\xF2\xBB-\xE6\xE7\xDD\x9B\xF2\xD5\xAB/\xDE><\xFD\n\xF4|\xFBS\xF7~\x9F\x9D\xF9\xEF5[\xBCj_-_\xBC\xFA\xE2\xA7\xCB\xFA\xBB\xE5O\xEC|\xF9\xF9\x8B\xF6'\x17\xBB_M\xCA\x9F\xDA\xF9.\xF5\x97S\x7F\xBF\xCF\x0F\x9E}\x99\xBF=\xDD\xA5\xFE\xDEf_\xDD\xFFE?\x81\xF7wV\xCDw\x17\xCD.\x8D\xFF\xF7~\xBDx\xF7\xD3\xD9O\xFF\xC4>\xF5\xFF\xE5\x94\xF0\xFD\x897/~\xE2'~P6\xDF}\xF3\x9D\x1A\xF8|\xB5\x98\xBF}\x05\xFA\xFC\xE4\xF4\x1D\xC6\xF3\x13D\xFFW\x9F\xB7\xF7\x89\x1EO\xF2\xB7\xBB_}\xF5{\xAF\xBE\x04=\xBE\xFBv\xF6\xF9\x17\xC4?\x18\xFFO\xEE~\x85\xF9\x05\x7F\xFC>_\xFD\xF4\xB3\x9F\xCE\x7F\xFA'O\xBE:\xFD\xE2~\xBEx\xF5\xEDW?\xFD\xE4\xEDwOw\xE8\xFBY\x96}\xFE\xEC\xF7\xCE\x9F\xBD\xC8h.?\xFD}~\xFAl\xE7\xF7\xDA}\xF6\xFB\xFC\x04\x8D\x7F\xF2\xE6\xED5\xE1\xF3\x8A\xE8s\xFD\xDD\xC5|\xFE\x93\xF7\xE6\xA0\xCF\xE7\xF9\x82\xF8\xF5\xA4\xFD\x89\xD7\xCF~\xEAS\xF0\xDB\xAB\x9F\\\xFD\xDE\xDF\xA5\xFE&?\xF9S\xF5\x9B\x9F\xA4\xF1\x13=\x7Fr\xB9\"\xFEY=\xA3\xF6\xD9\xF4\xF3\xEF\x10=\xDA\x17D\xBF\xFD\x9Fz6\xFFr\xF2\xF9\x8B\xFA\xAB\xC5\xBBl\xF2\xDDw\xBB\xF4\xFD+\xD0\x87\xF8\x81\xF0\xB9O\xFC\xD9\xD2|\xAD\x88\x1F~2\xFB\xC9\xDDg\xF7\x85?\xBE\xB8\xFE\xC9e\xF9\x9A\xC6\xDF\xD2\xF8w\xE9\xFB\xD37\xAF[\xA2\xCF\xDBw\xBF\xCF\x0F\xBEC\xF4\xFD\xCE\xB7\x89\xDEs\x9A\xBF\xE6\xBBo_\xBD z\x9DE\xFA\xFF\xF2\x15\xF5O\xFC\xF9\xDD\xBC\\\xFD>\xAF\xDF\x02\xFE\xEA\xEA\xF7Y\xEC~7\xDB\xB9\x7FJ\xFC\x1A\xE9\xFF\xF4\x1D\xF5\x7F\x8F\xE6\xF7\xF7y\x83\xF9\xD9\xFD\x0E\xCD\xD7n3\xA3\xF1~\xF5\xE6\x19\xE4\xED\x8A\xE6\xFF\xE4\xAB\x9F$x4\xFE/J\xC8\xD3\x17\xF7\x89\x1F\xCF~\xA2|\x86\xFE\xAF\x88\xFF^\x11>\xDF\x9E|{\xF6\xD3$\x8F\xBB$\xDF\x84\xEF\xEA\xF7!\xF9\xFE\xEE\xEB\xCF\xDF\xDDc~!\xFAn\xFC\xFEs\x9E\x8F7?\xF9\x83\xAF\xAE@o\xC8\xEBW\xE5\x8B\x9F\xFA\xEE3\x96W\xC2o\xE3\xF7\xFB\x8C\xCF\xDB\xFB\xC0\xE7\x17\xFD>_\xCDH\xBE^={\xB5(\x7F\x9A\xF8\xF5\xFEw\xBF\xFB\xEE\xF7\xCA>\x7F\x05\xF9\"z\x96<\x9E7\xA0\xCFb5\x87\xBC\xFF\xD4\xE9O~\x9E\x11\xFDI\x1F\xFC\xD4\x84\xE4\x8B\xF0\xFBI\x1A\xCF\xD9O\x80\x1Fv\xBFs*\xF0\x88\xBE\xCB\x17D\x8F\xD9\xDE\xEF\xB33\xFB|\xFAl\xF5\xEC\xCD\xE2!\xE4\t\xF3{\xCFk\x7F\xF2\xDD\x9F\xFE\xCEw\xA9\x7F\xD0\x9B\xF8\xFF;\xD5\xEF\xF3\x93\xB3\xD7?QV4\xBF\xA4\xAFh~\xF0\xFE\v\x92\a\xFE\xFB\xAB\xFB\x97\xDF\xA5\xF9\x06\xBDg\xD7\x8C\xDF\xBD\xEF\xFE\xE4\x1C\xFA\x11\xFA\xEB\xD5\x17\x8B9\xC9\xFB\xCE\xEE\xE4\xF3\xEF\x00\xDEO\x91|\xFF\xA2\xDF\xE7\r\xC1\xFF\xC9\xD53\x9A\xBF\xB7\x937\xE5\x15\xC9\xCFO\xFE^;\xBB\x9F\xBE\xFA\xBDg_\xBE\xFA\xBC\xB9z\xF3{\x13\xBD\xCA\xB2%\xFD2\xFF\xA2\xFC\xA9\xDD\xEF\xBE\xFD\xC9\x86\xF0i\xBF\xFC\xBD\x9F\xFC\xD4\x17%\xE4e\xD6\xE4\x8B/~@\xFA\xE4\xA7\x89/X\xBF|\xF1\xF9\x8Buv\xDD~\xF7'\xDF\xEE\x10\xFF|g\xE8\xFB\x9F }\xF5\xE9\xEF\xF3\x83\x17\xDF\x05\x7F\xBFY\xFE\xD4[\xCC\xC7\xEF\xB3w\xBF\xF9\x89\xB7\xBB\x9F\xBE\xF8\xC9\x9F\xFA\xC9/N\xBF\x1A|\x7Fr\xFA\x9D\x179\xE4\xFF\xBB\xD0\x7F\xA7W/\xBE;\x17\xF9\xDD{G\xF3\xF1\x13\xEF^\xBF\x9D\xBF\xFA\xC97\xAF\x96_\xBDyR\xFDD\xF9\xD5\xD5O~w\xF6*\xDB\xF9\xA9\x97_\xDD+O\xDE\xEC>\xFB\x8A\xE4\a\xE3\xDF\xFD}\xDE\x1C\xEF\x92\xFE\xFD\xBD1\x9F\xAFv\xEEW\xA4O_\xFF\xE4w\x7F\xF2\xF7\xF9\x89\xC5\xBB\x9F\xA0\xFE\xDE|U\xFE\xE4\xEB\xD7%\xCD\"\xB5'\xFDu\xFF\xBBo\x7F\xEA\xF5\x8B\xEF\xBE\xE0\xF9\x7F}\xFA\x9D\xFB\xC4\xAF$\x9F_\xFC\xE0\xCD\xDB\x17\xE5O>\xFD\xC9\xDF\xFB\xAB\xDDW\xC4_/\xCE^/\xA9}I\xFA\xE1\aO~\xAF\x17$\xAF\xF9\xB7g?\xF5\xDD\xCFa\x7F\b\xFFg_]\xD3|gd\xAF\x88\xDF\xDEe\xAFK\xD8\x8F\xA1\xEFW\xFB\xF9O\x92>Z\xBC\xFB\xC9\xEF>\xFB\xA9=\xC2\xE4\xBB\xAFK\x9E?\xE2\a\xE6\xAF\xEF~\xB5x\xF5{\x7F\xF9\xE6I\xF6\x93l\xBFV\xFB\xD4\x7F;\xF9\xFC>\xE4\xBB\xFA}\xDE\xFE\xE4\xE7\xB3\xCF\xCFH\xBF\x10\x7F\x10\xBF\xBCyzv?\xFF\xEE\xB3\xDF\xFB\xA7\xBEM\xFA\xE7\xAB\x9F\xFA\xC1W\xA4\x1FI^\xC1\x1F\xC4\x8F\xF3\xF6\xA7\xBE\xFA)\xC3\xDF/~\xE2\a\xAF\xEEA>'\xDF\xFD\xC9\xCF_\xB3>%\xFA\x9E\xCE\xBE\xFC\xE2\xBB/\xD6\xA4\x7F\xE9\xFD\xFD]g\xEF^\x90\xBD\x82=\xFB\xCE\xC0\xF7\x84\xEFW\xDF\xA9~\x8A\xFA#\xFE[\x93\xBC\x91|\xDD\xBFG\xFAs\x97\xF4\v}\xBFC>\x80\xB3\xFB/\xBF\xFDb\xF5S{\xF7\xE7\xB3o\xFF\xE45\xF9\v\xF7_\xFC\xA0|\xF2b\xE7\xF7\xB9\xF7\xEA\xED\x17;_\xBE9}\xF7\xC5\x0F.\xAE^\xBD\x99\xBE{\xF1t\xBA\xF7\xC5\xE9\xE9\xBB/\xBF\xFA\xCE\xD3/O\x7F\xEAs\xD2q\xBB\xAF\x9E~\xB1\xF7\xE2\xA7\xBF\xDA\xF9\x89\x1F\x9C\xED\x12\x0F]\xFF\xC4\x0F\x8E\xAF~\xE2\xA7\x7F\x9F{/\xDE\\\xD0\xDF_\xEC}\xF9\xE6\xAB\xBD\x17o\xDE\xDE\x7Fy\xF2\xF0\a\xD9wg\xEB\xDF\xE7\xF7~\xB5;]|\xF5\t\xFD\xFD\x13\xBF\xCF\xEF]\xB6?\xF5\xDD\xFB;_-~\xF2\a\xD3\xCF\x1F\xAE\xA7{_}\xF2\xFF\x00j\xEF\xFA\x93\xC4\b\x00\x00"
      read 2013 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to demo2.2c2p.com:443...
      opened
      starting SSL for demo2.2c2p.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- \"POST /2C2PFrontEnd/SecurePayment/Payment.aspx HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: demo2.2c2p.com\r\nContent-Length: 1199\r\n\r\n\"
      <- \"paymentRequest=[FILTERED]
      -> \"HTTP/1.1 200 OK\r\n\"
      -> \"Date: Thu, 03 Sep 2020 19:14:34 GMT\r\n\"
      -> \"Content-Type: text/html; charset=utf-8\r\n\"
      -> \"Content-Length: 2013\r\n\"
      -> \"Connection: close\r\n\"
      -> \"Cache-Control: private\r\n\"
      -> \"Content-Encoding: gzip\r\n\"
      -> \"Vary: Accept-Encoding\r\n\"
      -> \"Server: Microsoft-IIS/10.0\r\n\"
      -> \"X-AspNet-Version: 4.0.30319\r\n\"
      -> \"X-Powered-By: ASP.NET\r\n\"
      -> \"\r\n\"
      reading 2013 bytes...
      -> \"\u001F?\b\u0000\u0000\u0000\u0000\u0000\u0004\u0000??\a`\u001CI?%&/m?{\u007FJ?J??t?\b?`\u0013$?@\u0010??????\u001DiG#)?*??eVe]f\u0016@????{???{???;?N'????\\fd\u0001l??J??!???\u001F?~|\u001F?\"^>{2??[N??^?????j?w?\a??f?`?????^y9?????\u007F????{?UN?/V???O^~\e??}??\u0013?|u?S'????{\u007F??w?????/g{g?/~?U??O\u007Fb??Ng????o~??O??\u000F??????/NwO?{?W?????W???Og?~????w;?-\u007F??/????\u0017???'?????^???_-\u007F????{?????O~?{?????/~?Y????~9?-\u007F?\u0017o????<??:??^????O?}U|Q~?A\u007F??'O???????}???~???????O????]??U?????o???|>????????9;???.?|u?v???\u00174???\"jO??^Q?'??????g????^=????~???~??|{??'w\u007F?'\t??g?????b????>???Y???O?n???~@???????7?y?????z6?~???????>]U?????????j????\u007F??????<{??O~z??O???ww?;??'????]??J?g???\u0015?/\t???????????7?i???S??~>?=???-?????/?><?\n?|?S?~????5[?j_-_???????O?|????'\u0017?_M???.??S\u007F??\u000F?}??=???f_??E???wV?w\u0017?.???~?x???O??>??????7/~?'~P6?}?\u001A?|???}\u0005????\u001D??\u0013D?W????\u001EO?_}?{??\u0004=??v??\u0017??\u0018?O?~??\u0005\u007F?>_?????\u007F?'O?:??~?x??W????wOw??Y?}??????h.??}~?l???}???\u0004?\u007F???5???s???|???????????????~?S???\\????&??S?????\u0013=\u007Fr?\"?Y=??????\u0010=?\u0017D???z6?r??????l??w???+????O???|??\u001F~2???g???????e??????w???7?[???w??\u000F?C?????s???o_? z?E???\u0015?O???\\?>??\u0002????Y?~7?\u007FJ?\u001A???\u001D?\u007F????y????\u000E??n3??~??\u0019?????$x4?/J??\u0017??\u001F?~?|?????^\u0011>?|{??$??$????!???????c~!?n??s??7?????@o??W???3?W?o?????????\u0017?>_?H?^={?(\u007F????w?????>\u007F\u0005?\"z?<?7??b5?????O~?\u0011?I\u001F?????I\u001A??O?\u001Fv?s*????\u0017D????3?|?l????!?\t?{?k\u007F????w?\u007F???;?????QV4???h~??\v?\a???????\u0006?g?????\u001C?\u0011???\u0017?9???????\u0000?O?|????\r????3????7?\u0015??O?^;?????g_????z?{\u0013??%?2?????????i??????\u0017%?e??/~@??/X?|???uv?~?'??\u0010?|g??? }????\u0017?\u0005\u007F?Y??[???w???????????/N?\u001A|\u007Fr??\u00179????\u007F?W/?;\u0017??{G??\u0013?^?????7??_?yR?D???O~w?*????_?+O??>???\a???}?\u001C????1??v?W?O_??w\u007F?????????|U????%?\"?'?u??o\u007F??????\u007F}????$?_????\u0017?O>??????W?_/?^/?}I??\aO~?\u0017$???g????a\u007F\b?g_]?|gd????e?K???W??O?>Z????>??=??K???\a??~?x?{\u007F??I??l?V??\u007F;??>??}??????H?\u0010\u007F\u0010??yzv???????M????W?\u001FI^?\u001F??????)??/~?\a??A>'????_?>%?????/?\u007F???]g?^???=??????W?~??#?[???|?G?s??\v}?C>???/??b?S{??o??5?\v?_??|?b??????\u0017;_?9}??\u000F.?^???{?t?????/????/O\u007F?s?q???~??????\u001F??\u0012\u000F]??\u000F??~?\u007F?{/?\\??_?}??\u0017o??\u007Fy??\a?wg????~?;]|?\t??\u0013???]?????;_-~?\a??\u001F??{_}??\u0000j????\b\u0000\u0000\"
      read 2013 bytes
      Conn close
    POST_SCRUBBED
  end
end
