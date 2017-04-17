#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class ResponseMapper
      def map_response(response, jsonResult)
        response.status = jsonResult['status'] unless jsonResult['status'].nil?
        response.conversation_id = jsonResult['conversationId'] unless jsonResult['conversationId'].nil?
        response.error_code = jsonResult['errorCode'] unless jsonResult['errorCode'].nil?
        response.error_message = jsonResult['errorMessage'] unless jsonResult['errorMessage'].nil?
        response.error_group = jsonResult['errorGroup'] unless jsonResult['errorGroup'].nil?
        response.locale = jsonResult['locale'] unless jsonResult['locale'].nil?
        response.system_time = jsonResult['systemTime'] unless jsonResult['systemTime'].nil?
      end
    end
  end
end

