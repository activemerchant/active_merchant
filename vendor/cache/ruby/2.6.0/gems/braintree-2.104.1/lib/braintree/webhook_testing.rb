module Braintree
  class WebhookTesting # :nodoc:
    def self.sample_notification(*args)
      Configuration.gateway.webhook_testing.sample_notification(*args)
    end
  end
end
