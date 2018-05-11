require 'test_helper'

class RemotePayuInTest < Test::Unit::TestCase
  def setup
    @gateway = PayuInGateway.new(fixtures(:payu_in))

    @amount = 1100
    @credit_card = credit_card('5123456789012346', month: 5, year: 2017, verification_value: 564)

    @options = {
      order_id: generate_unique_id
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'No Error', response.message
  end

  def test_successful_purchase_with_full_options
    response = @gateway.purchase(
      @amount,
      @credit_card,
      order_id: generate_unique_id,
      description: "Awesome!",
      email: "jim@example.com",
      billing_address: {
        name: "Jim Smith",
        address1: "123 Road",
        address2: "Suite 123",
        city: "Somewhere",
        state: "ZZ",
        country: "US",
        zip: "12345",
        phone: "12223334444"
      },
      shipping_address: {
        name: "Joe Bob",
        address1: "987 Street",
        address2: "Suite 987",
        city: "Anyplace",
        state: "AA",
        country: "IN",
        zip: "98765",
        phone: "98887776666"
      }
    )

    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(0, @credit_card, @options)
    assert_failure response
    assert_match %r{invalid amount}i, response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(100, '')
    assert_failure response
  end

  def test_3ds_enrolled_card_fails
    response = @gateway.purchase(@amount, credit_card("4012001037141112"), @options)
    assert_failure response
    assert_equal "3D-secure enrolled cards are not supported.", response.message

=begin
    # This is handy for testing that 3DS is working with PayU
    response = response.responses.first

    # You'll probably need a new bin from http://requestb.in
    bin = "<requestb.in key>"
    File.open("3ds.html", "w") do |f|
      f.puts %(
        <html>
        <body>
          <form action="#{response.params["post_uri"]}" method="POST">
            <input type="hidden" name="PaReq" value="#{response.params["form_post_vars"]["PaReq"]}" />
            <input type="hidden" name="MD" value="#{response.params["form_post_vars"]["MD"]}" />
            <input type="hidden" name="TermUrl" value="http://requestb.in/#{bin}" />
            <input type="submit" />
          </form>
        </body>
        </html>
      )
    end
    puts "Test 3D-secure via `open 3ds.html`"
    puts "View results at http://requestb.in/#{bin}?inspect"
    puts "Finalize with: `curl -v -d PaRes='' -d MD='' '#{response.params["form_post_vars"]["TermUrl"]}'`"
=end
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    refute_match %r{[^\d]#{@credit_card.verification_value}(?:[^\d]|$)}, "Expected CVV to be scrubbed out of transcript"
  end

  def test_invalid_login
    gateway = PayuInGateway.new(
      key: '',
      salt: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
