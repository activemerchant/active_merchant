#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
      module CardStorage
        module Request
          class CreateCardRequest < Iyzipay::Client::Request
            attr_accessor :externalId
            attr_accessor :email
            attr_accessor :cardUserKey
            attr_accessor :card

            def get_json_object
              JsonBuilder.from_json_object(super).
                  add('externalId', @externalId).
                  add('email', @email).
                  add('cardUserKey', @cardUserKey).
                  add('card', @card).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:externalId, @externalId).
                  append(:email, @email).
                  append(:cardUserKey, @cardUserKey).
                  append(:card, @card).
                  get_request_string
            end
          end
        end
      end
    end
  end