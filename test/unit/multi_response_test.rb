require 'test_helper'

class MultiResponseTest < Test::Unit::TestCase
  def test_initial_state
    r = MultiResponse.new
    assert r.success?
    assert_nil r.params
    assert !r.test?
  end

  def test_processes_sub_requests
    r1 = Response.new(true, "1", {})
    r2 = Response.new(true, "2", {})
    m = MultiResponse.run do |r|
      r.process{r1}
      r.process{r2}
    end
    assert_equal [r1, r2], m.responses
  end

  def test_run_convenience_method
    r1 = Response.new(true, "1", {})
    r2 = Response.new(true, "2", {})
    m = MultiResponse.run do |r|
      r.process{r1}
      r.process{r2}
    end
    assert_equal [r1, r2], m.responses
  end

  def test_proxies_last_request
    m = MultiResponse.new

    r1 = Response.new(
      true,
      "1",
      {"one" => 1},
      :test => true,
      :authorization => "auth1",
      :avs_result => {:code => "AVS1"},
      :cvv_result => "CVV1",
      :fraud_review => true
    )
    m.process{r1}
    assert_equal({"one" => 1}, m.params)
    assert_equal "1", m.message
    assert m.test
    assert_equal "auth1", m.authorization
    assert_equal "AVS1", m.avs_result["code"]
    assert_equal "CVV1", m.cvv_result["code"]
    assert m.test?
    assert m.fraud_review?

    r2 = Response.new(
      true,
      "2",
      {"two" => 2},
      :test => false,
      :authorization => "auth2",
      :avs_result => {:code => "AVS2"},
      :cvv_result => "CVV2",
      :fraud_review => false
    )
    m.process{r2}
    assert_equal({"two" => 2}, m.params)
    assert_equal "2", m.message
    assert !m.test
    assert_equal "auth2", m.authorization
    assert_equal "AVS2", m.avs_result["code"]
    assert_equal "CVV2", m.cvv_result["code"]
    assert !m.test?
    assert !m.fraud_review?
  end

  def test_proxies_first_request_if_marked
    m = MultiResponse.new(:use_first_response)

    r1 = Response.new(
      true,
      "1",
      {"one" => 1},
      :test => true,
      :authorization => "auth1",
      :avs_result => {:code => "AVS1"},
      :cvv_result => "CVV1",
      :fraud_review => true
    )
    m.process{r1}
    assert_equal({"one" => 1}, m.params)
    assert_equal "1", m.message
    assert m.test
    assert_equal "auth1", m.authorization
    assert_equal "AVS1", m.avs_result["code"]
    assert_equal "CVV1", m.cvv_result["code"]
    assert m.test?
    assert m.fraud_review?

    r2 = Response.new(
      true,
      "2",
      {"two" => 2},
      :test => false,
      :authorization => "auth2",
      :avs_result => {:code => "AVS2"},
      :cvv_result => "CVV2",
      :fraud_review => false
    )
    m.process{r2}
    assert_equal({"one" => 1}, m.params)
    assert_equal "1", m.message
    assert m.test
    assert_equal "auth1", m.authorization
    assert_equal "AVS1", m.avs_result["code"]
    assert_equal "CVV1", m.cvv_result["code"]
    assert m.test?
    assert m.fraud_review?
  end

  def test_primary_response_always_returns_the_last_response_on_failure
    m = MultiResponse.new(:use_first_response)

    r1 = Response.new(true, "1", {}, {})
    r2 = Response.new(false, "2", {}, {})
    r3 = Response.new(false, "3", {}, {})
    m.process{r1}
    m.process{r2}
    m.process{r3}
    assert_equal r2, m.primary_response
    assert_equal '2', m.message
  end

  def test_stops_processing_upon_failure
    r1 = Response.new(false, "1", {})
    r2 = Response.new(true, "2", {})
    m = MultiResponse.run do |r|
      r.process{r1}
      r.process{r2}
    end
    assert !m.success?
    assert_equal [r1], m.responses
  end

  def test_merges_sub_multi_responses
    r1 = Response.new(true, "1", {})
    r2 = Response.new(true, "2", {})
    r3 = Response.new(true, "3", {})
    m1 = MultiResponse.run do |r|
      r.process{r1}
      r.process{r2}
    end
    m = MultiResponse.run do |r|
      r.process{m1}
      r.process{r3}
    end
    assert_equal [r1, r2, r3], m.responses
  end

  def test_handles_ignores_optional_request_result
    m = MultiResponse.new

    r1 = Response.new(true, "1")
    m.process{r1}
    assert_equal "1", m.message
    assert_equal [r1], m.responses

    r2 = Response.new(false, "2")
    m.process(:ignore_result){r2}
    assert_equal "1", m.message
    assert_equal [r1, r2], m.responses

    assert m.success?
  end
end
