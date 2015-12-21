#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Request
        class RetrieveCardListRequest < Iyzipay::Client::Request
          attr_accessor :cardUserKey

          def get_json_object
            super.merge(
                'cardUserKey' => @cardUserKey
            )
          end

          def to_PKI_request_string
            PKIRequestStringBuilder.new.append_super(super).
                append(:cardUserKey, @cardUserKey).
                get_request_string
          end
        end
      end
    end
  end
end
