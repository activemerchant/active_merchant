require 'test_helper'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class VposGateway
      def one_time_public_key
        OpenSSL::PKey::RSA.new(2048)
      end
    end
  end
end

class VposTest < Test::Unit::TestCase
  def setup
    @gateway = VposGateway.new(public_key: 'some_key', private_key: 'some_other_key', encryption_key: OpenSSL::PKey::RSA.new(512))
    @credit_card = credit_card
    @amount = 10000

    @options = {
      commerce: '123',
      commerce_branch: '45'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '701175#233024225526089', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '57', response.error_code
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response

    assert_equal '707860#948868617271843', response.authorization
    assert response.test?
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'RefundsServiceError:TIPO DE TRANSACCION NO PERMITIDA PARA TARJETAS EXTRANJERAS', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('123#456')
    assert_success response
    assert_equal 'RollbackSuccessful:Transacción Aprobada', response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(nil)
    assert_failure response
    assert_equal 'AlreadyRollbackedError:The payment has already been rollbacked.', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~TRANSCRIPT
      opening connection to vpos.infonet.com.py:8888...
      opened
      starting SSL for vpos.infonet.com.py:8888...
      SSL established
      <- "POST /vpos/api/0.3/application/encryption-key HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: vpos.infonet.com.py:8888\r\nContent-Length: 106\r\n\r\n"
      <- "{"public_key":"joszzJzNMkn6SKn0a5P9GcMw1HqZjC1u","operation":{"token":"683137179e606c700805e7773751b705"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.18.0\r\n"
      -> "Date: Tue, 06 Apr 2021 01:56:12 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "1a6\r\n"
      reading 422 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03e\x91K\x93\xA20\x00\x84\xFF\xCA\x14\xD7\xDD-QWe\xF6\x16H\x80\x00Fq\xE4!E\xD5\x96\x13\x94wT\x12\x84\xB8\xB5\xFF}u\xAE\xDB\xA7\xAE\xFE.\xDD\xD5\x7F\x14.\x8E\xA2\xE7\xCA/\x85\xF7\x94\x9E8W\xBE+'F;y\x15\xE5\x85\xFD\xAEO\xF2\x89~\xBC\xA4#\v\x93\xB7m\xA0{\xD8xs\xD1\xE1+L\xD9\x1Ac\x1DW\x80\xE8y}+\xEA\xD2z\x1FT\x1D\xF8\xC8\x04`c\x00_\x03/n\xE4\xEE\xD3#p\x93\xC0@\x0E0>\xAF\xD1\x81Q\xF3>\xEF!N\x99\xEF\xCC\xBD\x82\xC7\x17\x1Fy\xB3f\x9C\xAD\xC3\xE8\f\x9Dlb\xD9\xB1D\xC70\xB43>\x8Do\xCB\x0E\x0FZ\xC1\xEF\xE3\xC2\xCC\xB22\xDA\x98\xCD6\xA2\xF7,&E\x9B2\x14s\xAF<4\x1F\x89\xD7\r\x8E1U\x17\xC2\xDA\x17A\xEE\xC8\xED#\xB0\xF1\xA2\xCF\xF5\x1C\xCC\x06]\xEC\xF2\xE1!+\xCA\xC7\x99]H\xEA\xD5$\x88o\xFD\x1E\xE8)\xCB\xC7\xB2\xDA8\xB2\x8E\xC6D}\x9C\xE2\x05\fa?\xC9\xD5\xB3OiI|UD\xA1\xF9y\xF5\x7F\x0E\xE2\x83\x11\xDET\x8E;q\xC2\xB6Y\xD5\xF1\x9Dm\xC3GC\x9E\x1D\x8E\x9Ef\x10\x86\xA5\xBA\x81\xAA\xD7;\xA5m\xA06\x0F`\xAD\xAE\x9A\x8B\x95\x8834\xE5\xE84\xFB\xD5\xD0\xEF\xE2\x15JB\xAER\xB3n\xC66\xC4\xA2\x1A\x10O\xD9\xB7\xED5\x98$r\x9C/\xF4\xDD\xB5\x8B\x96\xD2>\xC4\x19;,\xB9\x06\x89h]w\xDA\xE5;\xB8\nGK\x9C\x93~\xDDV\x13\x88\x9DNK\x102\x1F\xCDL\xA3n\xCA\xC8\x80!\xF0_{\xBE\xCEA\x04\xFE\xFF\x97\xF2\xF7\x1Fe\xDC\xA8\x0E\xF4\x01\x00\x00"
      read 422 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to vpos.infonet.com.py:8888...
      opened
      starting SSL for vpos.infonet.com.py:8888...
      SSL established
      <- "POST /vpos/api/0.3/pci/encrypted HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: vpos.infonet.com.py:8888\r\nContent-Length: 850\r\n\r\n"
      <- "{"public_key":"joszzJzNMkn6SKn0a5P9GcMw1HqZjC1u","operation":{"token":"e0ca140e32edb506b20f47260b97b1ad","commerce":232,"commerce_branch":77,"shop_process_id":552384714818596,"number_of_payments":1,"recursive":false,"amount":"1000.00","currency":"PYG","card_encrypted_data":"eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkExMjhHQ00ifQ.bWLbgRHAl7GmGveBFEoi64bX472TQao5lCausaMSB2LsES8StjWxPbAZpfrFZDcWksnD2WfDbajSX11WsJJApohjp5fawPP30QcDjmSG-I9WXVnW_Qm-mcrejc82Km8A76-pr9aZd_od81QfQCYwOzpA6V_fz1zY_s8oWBBoudBThDQ__fhazJS5UXM8qMWtooUEmsiiGNDlv-0QTvWAQ-ShhZSDeMRQW6E6p8Jo-1rAlaPEpY2a9yUwT1Emq8eqWz6Fb3w6LA2fUCA1-aXwzfm1vs-LQ2ISgEugMU19gYqhl6qKLNXOJs0KkJCCuKutlHC9zbDPoKU8oO0cDSOfNg.6xi5G9fBauLK2c6p.1pF9qw6fMJyfbNU8y0Hi_x4WNH8GZASuZS6tNpfhnJjhUmdHHcEBV-WGF5FoKw.r4cVO2MlpKe229paSt2D1Q","card_month_expiration":"08","card_year_expiration":"21","additional_data":null}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.18.0\r\n"
      -> "Date: Tue, 06 Apr 2021 01:56:21 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "147\r\n"
      reading 327 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03U\x91\xCBn\xC3 \x10E\x7F%b\x1DY\x80\x9F\xF1\xCE\xABn\xBA\xA8\x9Av\xD1\x15\xC20VPb\xB0xTI\xA3\xFC{\aWU\xDD\x1D\xC3p\xE7\x9E\xB9\xDCI\x882\xA6@z\x12\x92R\x10\x02\xD9\x13\xE5\xECd\xFC,\xA3q\x96\xF4w\x12\xDD\x19\xF0@\xDAV\xB7S5\xF2\t\xA4\xEE\xBAj*\x99\xAC&\xD6\x8CeS\xD2j\x1C\x19J\xC3\xC9-b\xF1.O\x12F\x93\xBE\xAEy\xD9U-\xAB:\xD6\xD5\x87fO<\x84\xC5\xD9\x008\xEF\x88\x82\xDFRh\x88\xD2\\2\xC8\xCB*\x97\xDA\xED\x8E\x88\x10&\xA9\xA2\xF3F\xCE`#\xA0B\xA6x\xC2\xFAk\xC5\x136\xCD#\xF8\fG9\xAD\e\xECG\xA3\xCE\x10\xFF\x1A\x9C\xB1\xF6\xD0\xF0\x86\xF1\xAD\x9Dr:#P\xFA\x9F!(o\x96\x9F\xBD\xC9\x9B\x976H\xA5\xD0f'q\xA7Qj\x89\xAF\xE1\x1A\xC1j\xD0b\x83\xBE\x91\xD9t\xB9`\x0E\xA0\x927\xF1&\x8C\x9D\xDC&J%\xBD\x16\xC1%\xAF\xB2\xFB3\x8ES)D7\x83\x17f\xC1\eF\xBB\x82\xD7e\xC1yS\xF02'\xBA*\x94K6\xFA[\x0Egx\x1D\x9E\xDE\x87\x0F\xEC|\x82\x0F\xEB\x0F\x11Z\x94y\r\x13\xCE\xE8\xA7\xE1Jz\xFAx<\xBE\x01eg ^\xDC\x01\x00\x00"
      read 327 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    TRANSCRIPT
  end

  def post_scrubbed
    transcript = <<~TRANSCRIPT
      opening connection to vpos.infonet.com.py:8888...
      opened
      starting SSL for vpos.infonet.com.py:8888...
      SSL established
      <- "POST /vpos/api/0.3/application/encryption-key HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: vpos.infonet.com.py:8888\r\nContent-Length: 106\r\n\r\n"
      <- "{"public_key":"joszzJzNMkn6SKn0a5P9GcMw1HqZjC1u","operation":{"token":"683137179e606c700805e7773751b705"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.18.0\r\n"
      -> "Date: Tue, 06 Apr 2021 01:56:12 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "1a6\r\n"
      reading 422 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03e\x91K\x93\xA20\x00\x84\xFF\xCA\x14\xD7\xDD-QWe\xF6\x16H\x80\x00Fq\xE4!E\xD5\x96\x13\x94wT\x12\x84\xB8\xB5\xFF}u\xAE\xDB\xA7\xAE\xFE.\xDD\xD5\x7F\x14.\x8E\xA2\xE7\xCA/\x85\xF7\x94\x9E8W\xBE+'F;y\x15\xE5\x85\xFD\xAEO\xF2\x89~\xBC\xA4#\v\x93\xB7m\xA0{\xD8xs\xD1\xE1+L\xD9\x1Ac\x1DW\x80\xE8y}+\xEA\xD2z\x1FT\x1D\xF8\xC8\x04`c\x00_\x03/n\xE4\xEE\xD3#p\x93\xC0@\x0E0>\xAF\xD1\x81Q\xF3>\xEF!N\x99\xEF\xCC\xBD\x82\xC7\x17\x1Fy\xB3f\x9C\xAD\xC3\xE8\f\x9Dlb\xD9\xB1D\xC70\xB43>\x8Do\xCB\x0E\x0FZ\xC1\xEF\xE3\xC2\xCC\xB22\xDA\x98\xCD6\xA2\xF7,&E\x9B2\x14s\xAF<4\x1F\x89\xD7\r\x8E1U\x17\xC2\xDA\x17A\xEE\xC8\xED#\xB0\xF1\xA2\xCF\xF5\x1C\xCC\x06]\xEC\xF2\xE1!+\xCA\xC7\x99]H\xEA\xD5$\x88o\xFD\x1E\xE8)\xCB\xC7\xB2\xDA8\xB2\x8E\xC6D}\x9C\xE2\x05\fa?\xC9\xD5\xB3OiI|UD\xA1\xF9y\xF5\x7F\x0E\xE2\x83\x11\xDET\x8E;q\xC2\xB6Y\xD5\xF1\x9Dm\xC3GC\x9E\x1D\x8E\x9Ef\x10\x86\xA5\xBA\x81\xAA\xD7;\xA5m\xA06\x0F`\xAD\xAE\x9A\x8B\x95\x8834\xE5\xE84\xFB\xD5\xD0\xEF\xE2\x15JB\xAER\xB3n\xC66\xC4\xA2\x1A\x10O\xD9\xB7\xED5\x98$r\x9C/\xF4\xDD\xB5\x8B\x96\xD2>\xC4\x19;,\xB9\x06\x89h]w\xDA\xE5;\xB8\nGK\x9C\x93~\xDDV\x13\x88\x9DNK\x102\x1F\xCDL\xA3n\xCA\xC8\x80!\xF0_{\xBE\xCEA\x04\xFE\xFF\x97\xF2\xF7\x1Fe\xDC\xA8\x0E\xF4\x01\x00\x00"
      read 422 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to vpos.infonet.com.py:8888...
      opened
      starting SSL for vpos.infonet.com.py:8888...
      SSL established
      <- "POST /vpos/api/0.3/pci/encrypted HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: vpos.infonet.com.py:8888\r\nContent-Length: 850\r\n\r\n"
      <- "{"public_key":"joszzJzNMkn6SKn0a5P9GcMw1HqZjC1u","operation":{"token":"e0ca140e32edb506b20f47260b97b1ad","commerce":232,"commerce_branch":77,"shop_process_id":552384714818596,"number_of_payments":1,"recursive":false,"amount":"1000.00","currency":"PYG","card_encrypted_data":"eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkExMjhHQ00ifQ.bWLbgRHAl7GmGveBFEoi64bX472TQao5lCausaMSB2LsES8StjWxPbAZpfrFZDcWksnD2WfDbajSX11WsJJApohjp5fawPP30QcDjmSG-I9WXVnW_Qm-mcrejc82Km8A76-pr9aZd_od81QfQCYwOzpA6V_fz1zY_s8oWBBoudBThDQ__fhazJS5UXM8qMWtooUEmsiiGNDlv-0QTvWAQ-ShhZSDeMRQW6E6p8Jo-1rAlaPEpY2a9yUwT1Emq8eqWz6Fb3w6LA2fUCA1-aXwzfm1vs-LQ2ISgEugMU19gYqhl6qKLNXOJs0KkJCCuKutlHC9zbDPoKU8oO0cDSOfNg.6xi5G9fBauLK2c6p.1pF9qw6fMJyfbNU8y0Hi_x4WNH8GZASuZS6tNpfhnJjhUmdHHcEBV-WGF5FoKw.r4cVO2MlpKe229paSt2D1Q","card_month_expiration":"08","card_year_expiration":"21","additional_data":null}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.18.0\r\n"
      -> "Date: Tue, 06 Apr 2021 01:56:21 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "147\r\n"
      reading 327 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03U\x91\xCBn\xC3 \x10E\x7F%b\x1DY\x80\x9F\xF1\xCE\xABn\xBA\xA8\x9Av\xD1\x15\xC20VPb\xB0xTI\xA3\xFC{\aWU\xDD\x1D\xC3p\xE7\x9E\xB9\xDCI\x882\xA6@z\x12\x92R\x10\x02\xD9\x13\xE5\xECd\xFC,\xA3q\x96\xF4w\x12\xDD\x19\xF0@\xDAV\xB7S5\xF2\t\xA4\xEE\xBAj*\x99\xAC&\xD6\x8CeS\xD2j\x1C\x19J\xC3\xC9-b\xF1.O\x12F\x93\xBE\xAEy\xD9U-\xAB:\xD6\xD5\x87fO<\x84\xC5\xD9\x008\xEF\x88\x82\xDFRh\x88\xD2\\2\xC8\xCB*\x97\xDA\xED\x8E\x88\x10&\xA9\xA2\xF3F\xCE`#\xA0B\xA6x\xC2\xFAk\xC5\x136\xCD#\xF8\fG9\xAD\e\xECG\xA3\xCE\x10\xFF\x1A\x9C\xB1\xF6\xD0\xF0\x86\xF1\xAD\x9Dr:#P\xFA\x9F!(o\x96\x9F\xBD\xC9\x9B\x976H\xA5\xD0f'q\xA7Qj\x89\xAF\xE1\x1A\xC1j\xD0b\x83\xBE\x91\xD9t\xB9`\x0E\xA0\x927\xF1&\x8C\x9D\xDC&J%\xBD\x16\xC1%\xAF\xB2\xFB3\x8ES)D7\x83\x17f\xC1\eF\xBB\x82\xD7e\xC1yS\xF02'\xBA*\x94K6\xFA[\x0Egx\x1D\x9E\xDE\x87\x0F\xEC|\x82\x0F\xEB\x0F\x11Z\x94y\r\x13\xCE\xE8\xA7\xE1Jz\xFAx<\xBE\x01eg ^\xDC\x01\x00\x00"
      read 327 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    TRANSCRIPT
    @gateway.remove_invalid_utf_8_byte_sequences(transcript)
  end

  def successful_purchase_response
    %({"status":"success","confirmation":{"token":"2e2f60bd985018defc145a2f5dc0060e","shop_process_id":233024225526089,"response":"S","response_details":"Procesado Satisfactoriamente","authorization_number":"701175","ticket_number":"2117959993","response_code":"00","response_description":"Transaccion aprobada","extended_response_description":null,"security_information":{"card_source":"L","customer_ip":"108.253.226.231","card_country":"PARAGUAY","version":"0.3","risk_index":0}}}
      )
  end

  def failed_purchase_response
    %({"status":"success","confirmation":{"token":"d08dd5bd604f4c4ba1049195b9e015e2","shop_process_id":845868143743681,"response":"N","response_details":"Procesado Satisfactoriamente","authorization_number":null,"ticket_number":"2117962608","response_code":"57","response_description":"Transaccion denegada","extended_response_description":"IMPORTE DE LA TRN INFERIOR AL M\u00bfNIMO PERMITIDO","security_information":{"card_source":"I","customer_ip":"108.253.226.231","card_country":"UNITED STATES","version":"0.3","risk_index":0}}})
  end

  def successful_credit_response
    %({"status":"success","refund":{"status":4,"request_token":"74845bf692d3ff78ce5d5c7d0d8ecdfa","shop_process_id":948868617271843,"origin_shop_process_id":null,"amount":"1000.0","currency":"PYG","commerce":232,"commerce_branch":77,"ticket_number":2117984322,"authorization_code":"707860","response_code":"00","response_description":"Transaccion aprobada","extended_response":null}})
  end

  def failed_credit_response
    %({"status":"error","messages":[{"level":"error","key":"RefundsServiceError","dsc":"TIPO DE TRANSACCION NO PERMITIDA PARA TARJETAS EXTRANJERAS"}]})
  end

  def successful_void_response
    %({"status":"success","messages":[{"dsc":"Transacción Aprobada","key":"RollbackSuccessful","level":"info"}]})
  end

  def failed_void_response
    %({"status":"error","messages":[{"level":"error","key":"AlreadyRollbackedError","dsc":"The payment has already been rollbacked."}]})
  end
end
