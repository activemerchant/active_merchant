module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

  	class OffsiteGateway

      # The session class models a session with the offsite gateway.
      #
      # Within a session, you have three objects that come in to play.
      # - The Redirect models how the user is redirected to the gateway to make the payment.
      # - The Return models the return to our own website.
      # - The Notification models any offline notifications the gateway may send.
      #
      # The session should have a unique identifier as session_id. The session's data
      # object can be used to store alimited amount of data about the session. You can
      # use it to store an external unique identifier that the gateway uses to refer to 
      # the session, or other 
      class Session

        attr_reader :gateway, :session_id, :data

        def initialize(gateway, session_id, data = {})
          @gateway, @session_id, @data = gateway, session_id, data
        end

        def redirect(options = {})
          gateway.class.const_get(:Redirect).new(self, options)
        end

        def return(request)
          gateway.class.const_get(:Return).new(self, request)
        end

        def notification(request)
          gateway.class.const_get(:Notification).new(self, request)
        end

        def notification_url
          gateway.notification_url % { :session_id => session_id }
        end

        def return_url
          gateway.return_url % { :session_id => session_id }
        end
      end

      # The redirect class models the redirect to the offsite gateway. 
      #
      #
      class Redirect

        attr_reader :session, :payment

        def initialize(session, payment = {})
          @session, @payment = session, payment
          @params = {}
        end

        def gateway
          @session.gateway
        end

        # Should return :redirect, or :post_form
        def type
          raise NotImplementedError, "Please implement the type method of the offsite gateway's Redirect class."
        end

        # The URL to redirect to. 
        # 
        # - For type :post_form, this value should be used for the action attribute of the form tag
        # - 
        def url
          raise NotImplementedError, "Please implement the url method of the offsite gateway's Redirect class."
        end

        # The parameters to include in the redirect.
        #
        # - For a 301 redirect, the will be included as query string parameters
        # - For a post form, these parameters should be rendered as (hidden) form fields.
        def params
          @params
        end
      end


      class Return
        def initialize(session, request)
          @session, @request = session, request
        end

        def gateway
          @session.gateway
        end        

        # should return :pending, :success, :failure, or :error
        def status
          :success
        end
      end

      # The Notification class models any offline notification that the gateway
      # may send to update us about the status of a payment.
      class Notification
        def initialize(session, request)
          @session, @request = session, request
        end

        def gateway
          @session.gateway
        end        
        
        # Should return the response that needs to be sent to the offsite payment gateway
        # to acknowledge the notification. It should be in Tack notation, i.e. 
        # [status, headers_hash, body_enumerable]
        # By default it will send an empty 200 OK response.
        def response
          [200, {}, []]
        end
      end

      def initialize(options = {})
        @options = options
      end

      # Starts a new session with this offsite payment gateway.
      def session(session_id, data = {})
        self.class.const_get(:Session).new(self, session_id, data)
      end
  	end
  end
end
