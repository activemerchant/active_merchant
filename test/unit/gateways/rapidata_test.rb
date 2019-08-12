require 'test_helper'

class RapidataTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = RapidataGateway.new(username: 'login', password: 'password', client_id: 'test_client')
    @checking_account = check(routing_number: 123456)
    @options = {
      billing_address: address.merge(county: 'Greater Manchester'),
      description: 'Store Purchase',
      database_id: 20040,
      frequency_id: 1,
      first_name: 'Bob',
      last_name: 'Longsen',
      first_collection_date: (Date.current + 1.month).change(day: 1)
    }
  end

  def test_successful_direct_debit_plan
    response = stub_comms do
      @gateway.recurring_debit(@amount, @checking_account, @options)
    end.respond_with(successful_oauth_token, successful_direct_debit_plan_response)

    assert_success response

    assert_equal 'efslrxoj38', response.authorization
    assert response.test?
  end

  def test_failed_direct_debit_plan
    fail_options = @options.merge(first_collection_date: Date.current)
    response = stub_comms do
      @gateway.create_direct_debit_plan(@amount, @checking_account, fail_options)
    end.respond_with(successful_oauth_token, failed_direct_debit_plan_response)

    assert_failure response
    assert_equal 'The request is invalid.', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_oauth_token
    {
      "access_token"=>"foobarsekritjwt",
      "token_type"=>"bearer",
      "expires_in"=>3599, "refresh_token"=>"72609d8d155a4ab9a84103f2fa7aaaeb",
      "roles"=>"Api",
      "memorableInfoPositions"=>"",
      "verified"=>"True",
      "passwordExpired"=>"False",
      "as:client_id"=>"test_client",
      ".issued"=>"Mon, 12 Aug 2019 02:34:03 GMT",
      ".expires"=>"Mon, 12 Aug 2019 03:34:03 GMT"
    }.to_json
  end

  def pre_scrubbed
    <<-PRESCRUB
opening connection to sandbox.rapidata.com:443...
opened
starting SSL for sandbox.rapidata.com:443...
SSL established
<- "POST /webapi/oauth/token HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.rapidata.com\r\nContent-Length: 158\r\n\r\n"
<- "grant_type=password&username=foo%40evergiving.com&password=bar&client_id=test_client&tenant=https%3A%2F%2Fsandbox.rapidata.com"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Pragma: no-cache\r\n"
-> "Content-Length: 926\r\n"
-> "Content-Type: application/json;charset=UTF-8\r\n"
-> "Expires: -1\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 12 Aug 2019 02:34:04 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 926 bytes...
-> "{\"access_token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1bmlxdWVfbmFtZSI6IjA1ODNkYTZhLTgzNjMtNDcwYi05ZTMxLWI4ZDA4OTExMDU3MyIsImlkIjoiMDU4M2RhNmEtODM2My00NzBiLTllMzEtYjhkMDg5MTEwNTczIiwidGVuYW50IjoiaHR0cHM6Ly9zYW5kYm94LnJhcGlkYXRhLmNvbSIsImltSWQiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAiLCJ1c2VyTmFtZSI6IkFQSUBldmVyZ2l2aW5nLmNvbSIsInZlcmlmaWVkIjoiVHJ1ZSIsInBhc3N3b3JkRXhwaXJlZCI6IkZhbHNlIiwicm9sZSI6IkFwaSIsImlzcyI6Imh0dHBzOi8vc2FuZGJveC5yYXBpZGF0YS5jb20iLCJhdWQiOiI1YzA3NmFjMmMxOWU0YzA3ODlhMmFmM2QyYTIxYzU5ZiIsImV4cCI6MTU2NTU4MDg0MywibmJmIjoxNTY1NTc3MjQzfQ.NTvuatT3AVhjuwnZiNfTC9SziT0GNV6lk2cZ8HtTNt0\",\"token_type\":\"bearer\",\"expires_in\":3599,\"refresh_token\":\"72609d8d155a4ab9a84103f2fa7aaaeb\",\"roles\":\"Api\",\"memorableInfoPositions\":\"\",\"verified\":\"True\",\"passwordExpired\":\"False\",\"as:client_id\":\"test_client\",\".issued\":\"Mon, 12 Aug 2019 02:34:03 GMT\",\".expires\":\"Mon, 12 Aug 2019 03:34:03 GMT\"}"
read 926 bytes
Conn close
opening connection to sandbox.rapidata.com:443...
opened
starting SSL for sandbox.rapidata.com:443...
SSL established
<- "POST /webapi/api/v1/customer/CreateDirectDebitPayer HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1bmlxdWVfbmFtZSI6IjA1ODNkYTZhLTgzNjMtNDcwYi05ZTMxLWI4ZDA4OTExMDU3MyIsImlkIjoiMDU4M2RhNmEtODM2My00NzBiLTllMzEtYjhkMDg5MTEwNTczIiwidGVuYW50IjoiaHR0cHM6Ly9zYW5kYm94LnJhcGlkYXRhLmNvbSIsImltSWQiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAiLCJ1c2VyTmFtZSI6IkFQSUBldmVyZ2l2aW5nLmNvbSIsInZlcmlmaWVkIjoiVHJ1ZSIsInBhc3N3b3JkRXhwaXJlZCI6IkZhbHNlIiwicm9sZSI6IkFwaSIsImlzcyI6Imh0dHBzOi8vc2FuZGJveC5yYXBpZGF0YS5jb20iLCJhdWQiOiI1YzA3NmFjMmMxOWU0YzA3ODlhMmFmM2QyYTIxYzU5ZiIsImV4cCI6MTU2NTU4MDg0MywibmJmIjoxNTY1NTc3MjQzfQ.NTvuatT3AVhjuwnZiNfTC9SziT0GNV6lk2cZ8HtTNt0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.rapidata.com\r\nContent-Length: 476\r\n\r\n"
<- "{\"CreateDirectDebitInput\":{\"Amount\":\"1.00\",\"GiftAid\":true,\"IsFulfilment\":false,\"AccountName\":\"Jim Smith\",\"AccountNumber\":\"15378535\",\"SortCode\":123456,\"address1\":\"456 My Street\",\"address2\":\"Apt 1\",\"town\":\"Ottawa\",\"county\":\"Greater Manchester\",\"FirstName\":\"Bob\",\"LastName\":\"Longsen\",\"Email\":\"longbob@example.com\",\"FrequencyId\":1,\"FirstCollectionDate\":\"2019-09-01\",\"DatabaseId\":20040,\"Source\":\"Evergiving\",\"Other1\":\"Something\",\"Other2\":\"To\",\"Other3\":\"Send\",\"Other4\":\"As a test\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Length: 66\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 12 Aug 2019 02:34:05 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 66 bytes...
-> "{\"ClientId\":0,\"URN\":\"efslrxoj38\",\"ValidationResult\":{\"errors\":[]}}"
read 66 bytes
Conn close
    PRESCRUB
  end

  def post_scrubbed
    <<-POSTCRUB
opening connection to sandbox.rapidata.com:443...
opened
starting SSL for sandbox.rapidata.com:443...
SSL established
<- "POST /webapi/oauth/token HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.rapidata.com\r\nContent-Length: 158\r\n\r\n"
<- "grant_type=password&username=[FILTERED]&password=[FILTERED]&client_id=test_client&tenant=https%3A%2F%2Fsandbox.rapidata.com"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Pragma: no-cache\r\n"
-> "Content-Length: 926\r\n"
-> "Content-Type: application/json;charset=UTF-8\r\n"
-> "Expires: -1\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 12 Aug 2019 02:34:04 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 926 bytes...
-> "{\"access_token\":\"[FILTERED]\",\"token_type\":\"bearer\",\"expires_in\":3599,\"refresh_token\":\"72609d8d155a4ab9a84103f2fa7aaaeb\",\"roles\":\"Api\",\"memorableInfoPositions\":\"\",\"verified\":\"True\",\"passwordExpired\":\"False\",\"as:client_id\":\"test_client\",\".issued\":\"Mon, 12 Aug 2019 02:34:03 GMT\",\".expires\":\"Mon, 12 Aug 2019 03:34:03 GMT\"}"
read 926 bytes
Conn close
opening connection to sandbox.rapidata.com:443...
opened
starting SSL for sandbox.rapidata.com:443...
SSL established
<- "POST /webapi/api/v1/customer/CreateDirectDebitPayer HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.rapidata.com\r\nContent-Length: 476\r\n\r\n"
<- "{\"CreateDirectDebitInput\":{\"Amount\":\"1.00\",\"GiftAid\":true,\"IsFulfilment\":false,\"AccountName\":\"Jim Smith\",\"AccountNumber\":\"[FILTERED]\",\"SortCode\":123456,\"address1\":\"456 My Street\",\"address2\":\"Apt 1\",\"town\":\"Ottawa\",\"county\":\"Greater Manchester\",\"FirstName\":\"Bob\",\"LastName\":\"Longsen\",\"Email\":\"longbob@example.com\",\"FrequencyId\":1,\"FirstCollectionDate\":\"2019-09-01\",\"DatabaseId\":20040,\"Source\":\"Evergiving\",\"Other1\":\"Something\",\"Other2\":\"To\",\"Other3\":\"Send\",\"Other4\":\"As a test\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Length: 66\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 12 Aug 2019 02:34:05 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 66 bytes...
-> "{\"ClientId\":0,\"URN\":\"efslrxoj38\",\"ValidationResult\":{\"errors\":[]}}"
read 66 bytes
Conn close
    POSTCRUB
  end

  def successful_direct_debit_plan_response
    {
      "ClientId" => 0,
      "URN" => "efslrxoj38",
      "ValidationResult" => {
        "errors" => []
      }
    }.to_json
  end

  def failed_direct_debit_plan_response
    {
      "Message" => "The request is invalid.",
      "ModelState" => {
        "Validation - First Collection Date Error"=> [
          "First collection date was not 10 working days in the future."
        ]
      }
    }.to_json
  end
end
