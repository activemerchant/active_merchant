#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Request
          class SubMerchantRequest < Iyzipay::Client::Request
            attr_accessor :name
            attr_accessor :email
            attr_accessor :gsmNumber
            attr_accessor :address
            attr_accessor :iban
            attr_accessor :taxOffice
            attr_accessor :contactName
            attr_accessor :contactSurname
            attr_accessor :legalCompanyTitle

            def get_json_object
              super.merge(
                  'name' => @name,
                  'email' => @email,
                  'gsmNumber' => @gsmNumber,
                  'address' => @address,
                  'iban' => @iban,
                  'taxOffice' => @taxOffice,
                  'contactName' => @contactName,
                  'contactSurname' => @contactSurname,
                  'legalCompanyTitle' => @legalCompanyTitle
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:name, @name).
                  append(:email, @email).
                  append(:gsmNumber, @gsmNumber).
                  append(:address, @address).
                  append(:iban, @iban).
                  append(:taxOffice, @taxOffice).
                  append(:contactName, @contactName).
                  append(:contactSurname, @contactSurname).
                  append(:legalCompanyTitle, @legalCompanyTitle).
                  get_request_string
            end
          end
        end
      end
    end
  end
end

