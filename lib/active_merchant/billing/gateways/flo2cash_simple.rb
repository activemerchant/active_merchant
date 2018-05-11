module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Flo2cashSimpleGateway < Flo2cashGateway
      self.display_name = 'Flo2Cash Simple'

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("ProcessPurchase", post)
      end

      # Flo2Cash's "simple mode" does not support auth/capture
      undef_method :authorize
      undef_method :capture
    end
  end
end
