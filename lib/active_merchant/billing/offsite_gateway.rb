module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

  	class OffsiteGateway

      # Exception to throw if something goes wrong building the redirect object.
      class RedirectError < ActiveMerchantError; end

      # Exception to throw if something goes wrong handling the return.
      class ReturnError < ActiveMerchantError; end

      # Exception to throw if something goes wrong handling an offline notification.
      class NotificationError < ActiveMerchantError; end


      # The session class models a session with the offsite gateway.
      #
      # Within a session, you have three objects that come in to play.
      # - The Redirect models how the user is redirected to the gateway to make the payment.
      # - The Return models the return to our own website.
      # - The Notification models any offline notifications the gateway may send.
      #
      # The session should have a unique identifier as session_id. The session's data
      # object can be used to store a limited amount of data about the session. You can
      # use it to store an external unique identifier that the gateway uses to refer to 
      # the session, or other data that is required to make the integration session work.
      class Session

        attr_reader :gateway, :session_id, :data

        def initialize(gateway, session_id, data = {})
          @gateway, @session_id, @data = gateway, session_id, data
        end

        # Constructs a Redirect instance for the session.
        def redirect(options = {})
          gateway.class.const_get(:Redirect).new(self, options)
        end

        # Constructs a Return instance for the session.
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
      # This instance is collect and format the parameters necessary to redirect
      # properly to the payment gateway, either using a form post, or using a 
      # HTTP 301 redirect.
      #
      # If for some reason the redirect fails, it should raise an RedirectError
      # exception, so it can handled properly.
      class Redirect

        attr_reader :session, :payment

        def initialize(session, payment = {})
          @session, @payment = session, payment
          @params = {}
        end

        # The OffsiteGateway instance for this session
        def gateway
          @session.gateway
        end

        # Should return :redirect, or :post_form
        def type
          raise NotImplementedError, "Please implement the type method of the offsite gateway's Redirect class."
        end

        # The URL to redirect to. 
        # 
        # - For type :post_form, this value should be used for the action attribute of the form tag.
        # - For type :redirect, this should not include any GET parameters - they will be added  
        #   automatically based on the result of the params method.
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


      # Models the information embedded it the return request. The main purpose
      # for this is to determine whether the payment was succeeded, failed, or
      # is still pending, so an appropriate page can be shown to the user.
      # 
      # If for some reason the return request cannot be interpreted, a
      # ReturnError should be thrown.
      class Return
        def initialize(session, request)
          @session, @request = session, request
        end

        # The OffsiteGateway instance for this session
        def gateway
          @session.gateway
        end        

        # should return :pending, :success, :failure
        def status
          raise NotImplementedError, "Please implement the status method of the offsite gateway's Return class."
        end
      end

      # The Notification class models any offline notification that the gateway
      # may send to update us about the status of a payment.
      #
      # If for some reason the notification cannot be interpreted, it should raise
      # a NotificationError
      class Notification
        def initialize(session, request)
          @session, @request = session, request
        end

        # The OffsiteGateway instance for this session
        def gateway
          @session.gateway
        end        
        
        # Should return the response that needs to be sent to the offsite payment gateway
        # to acknowledge the notification after it has been processed successfully.. 
        #
        # It should be in Rack format, i.e. [status, headers_hash, body_enumerable]
        # By default it will send an empty 200 OK response.
        def success_response
          [200, {}, []]
        end

        # Should return the response that needs to be sent to the offsite payment gateway
        # to acknowledge the notification if it could not be processed successfully. 
        #
        # The exception argument will be set to the exception that occured during the 
        # the processing.
        #
        # It should be in Rack format, i.e. [status, headers_hash, body_enumerable]
        # By default it will send an empty 400 Bad request response.
        def failure_response(exception = nil)
          [400, {}, []]
        end
      end

      # This module specifies all the methods that declare what features this
      # offsite gateway supports or what functionality it requires. 
      #
      # This module is extended into the base class, with basic implementations, and 
      # subclasses can overwrite the specific methods if needed.
      module GatewayFeatureSupport

        # This method should return true if this gateway requires persistent sessions,
        # which means that the Session's data object will be persistent between the 
        # redirect and the return.
        def requires_persistent_sessions?
          false
        end

        # This method should return true if this gateway requires the user to set an 
        # additional parameter before it can redirect to this gateway successfully.
        #
        # For instance, some gateways may require you to select 
        def requires_redirect_param?
          false
        end

        # This method should return true if the payment gateway supports
        # setting a different return URL for every session.
        def supports_session_return_url?
          true
        end

        # This method should return true if the payment gateway supports
        # setting a different notification URL for every session.
        def supports_session_notification_url?
          true
        end
      end

      extend GatewayFeatureSupport

      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      # Starts a new session with this offsite payment gateway.
      def session(session_id, data = {})
        self.class.const_get(:Session).new(self, session_id, data)
      end

      # The URL to send notifications to.
      #
      # If it includes %{session_id}, it will be replaced by the session_id. This way,
      # you can easily look up the session related to the notification.
      def notification_url
        options[:notification_url]
      end

      # The URL to return two after the payment is finished.
      #
      # If it includes %{session_id}, it will be replaced by the session_id. This way,
      # you can easily look up the session related to the notification.
      def return_url
        options[:return_url]
      end
  	end
  end
end
