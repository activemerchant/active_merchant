#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
      module CardStorage
        module Request
          class DeleteCardRequest < Iyzipay::Client::Request
            attr_accessor :cardUserKey
            attr_accessor :cardToken

            def get_json_object
              super.merge(
                  'cardUserKey' => @cardUserKey,
                  'cardToken' => @cardToken
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:cardUserKey, @cardUserKey).
                  append(:cardToken, @cardToken).
                  get_request_string
            end
          end
        end
      end
    end
  end
