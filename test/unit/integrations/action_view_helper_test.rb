require 'test_helper'

class ActionViewHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations::ActionViewHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::CaptureHelper
  include ActionView::Helpers::TextHelper

  attr_accessor :output_buffer

  def setup
    @controller = Class.new do
      attr_reader :url_for_options
      def url_for(options, *parameters_for_method_reference)
        @url_for_options = options
      end      
    end
    @controller = @controller.new
    @output_buffer = ''
  end

  def test_basic_payment_service
    _erbout = payment_service_for('order-1','test', :service => :bogus){}

    expected = [
      /^<form.*action="http:\/\/www.bogus.com".*/,
      /<input id="account" name="account" type="hidden" value="test" \/>/,
      /<input id="order" name="order" type="hidden" value="order-1" \/>/,
      /<\/form>/
    ]

    _erbout.split("\n").reject(&:blank?).each_with_index do |line, index|
      assert_match expected[index], line.chomp, "Failed to match #{line}"
    end
  end

  def test_payment_service_no_block_given
    assert_raise(ArgumentError){ payment_service_for }
  end

  protected
  def protect_against_forgery?
    false
  end
end

if "".respond_to? :html_safe?
  class ActionView::Base
    include ActiveMerchant::Billing::Integrations::ActionViewHelper
    include ActionView::Helpers::FormHelper
    include ActionView::Helpers::FormTagHelper
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::CaptureHelper
    include ActionView::Helpers::TextHelper
  end

  class PaymentServiceController < ActionController::Base
    begin
      require 'rails'
      class MerchantApp < Rails::Application; end
      include Rails.application.routes.url_helpers
    rescue NameError, LoadError; end

    def payment_action
      render :inline => "<% payment_service_for('order-1','test', :service => :bogus){} %>"
    end
  end

  class PaymentServiceControllerTest < ActionController::TestCase
    def test_html_safety
      with_routing do |set|
        set.draw { |map| map.connect ':controller/:action/:id' }

        get :payment_action

        expected = [
          /^<form.*action="http:\/\/www.bogus.com".*/,
          /<input id="account" name="account" type="hidden" value="test" \/>/,
          /<input id="order" name="order" type="hidden" value="order-1" \/>/,
          /<\/form>/
        ]
 
        @response.body.split("\n").reject(&:blank?).each_with_index do |line, index|
          assert_match expected[index], line.chomp, "Failed to match #{line}"
        end
      end
    end
  end
end
