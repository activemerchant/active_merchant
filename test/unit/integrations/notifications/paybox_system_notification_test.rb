require 'test_helper'

class PayboxSystemNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paybox_system = PayboxSystem::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @paybox_system.complete?
    assert_equal "00000", @paybox_system.status
    assert_equal CGI.unescape("ZOxcZvegFEZbLnDUOKeS3kNkL7YbVJpVFQi9YYxuqe5wcvNIAw%2BmcxODwjg09Y9s3xd%2BweQ79nQtnL19O0sjDRqy5svZsxFOy7GRZKisruSIjveeH7ZYmwb0z7Th9WZtv%2FjdSZwcMQ%2BQ%2FlYOBwm4ufoWYgREBo5HCdIDcctJZdg%3D"), @paybox_system.transaction_id
    assert_equal "8", @paybox_system.item_id
    assert_equal "3245", @paybox_system.gross
    assert_equal "EUR", @paybox_system.currency
    assert @paybox_system.test?
  end

  def test_compositions
    assert_equal Money.new(@paybox_system.gross.to_i, 'EUR'), @paybox_system.amount
  end

  def test_acknowledge
    assert @paybox_system.respond_to?(:acknowledge)
    assert @paybox_system.acknowledge
  end

  private
  def http_raw_data
    "amount=3245&reference=8&autorization=XXXXXX&error=00000&sign=ZOxcZvegFEZbLnDUOKeS3kNkL7YbVJpVFQi9YYxuqe5wcvNIAw%2BmcxODwjg09Y9s3xd%2BweQ79nQtnL19O0sjDRqy5svZsxFOy7GRZKisruSIjveeH7ZYmwb0z7Th9WZtv%2FjdSZwcMQ%2BQ%2FlYOBwm4ufoWYgREBo5HCdIDcctJZdg%3D"
  end
end
