#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Response
        module Mapper
          class RetrieveCardListResponseMapper < ResponseMapper

            def map_response(response, jsonResult)
              super
              response.card_user_key = jsonResult['cardUserKey'] unless jsonResult['cardUserKey'].nil?
              response.card_details = map_card_details(jsonResult['cardDetails']) unless jsonResult['cardDetails'].nil?
            end

            def map_card_details(card_details)
              card_detail_dtos = Array.new
              card_details.each do |card_detail|
                card_detail_dto = Dto::CardDetailDto::new
                card_detail_dto.cardToken = card_detail['cardToken'] unless card_detail['cardToken'].nil?
                card_detail_dto.cardAlias = card_detail['cardAlias'] unless card_detail['cardAlias'].nil?
                card_detail_dto.binNumber = card_detail['binNumber'] unless card_detail['binNumber'].nil?
                card_detail_dto.cardType = card_detail['cardType'] unless card_detail['cardType'].nil?
                card_detail_dto.cardAssociation = card_detail['cardAssociation'] unless card_detail['cardAssociation'].nil?
                card_detail_dto.cardFamily = card_detail['cardFamily'] unless card_detail['cardFamily'].nil?
                card_detail_dto.cardBankCode = card_detail['cardBankCode'] unless card_detail['cardBankCode'].nil?
                card_detail_dto.cardBankName = card_detail['cardBankName'] unless card_detail['cardBankName'].nil?
                card_detail_dtos << card_detail_dto
              end
              card_details
            end

          end
        end
      end
    end
  end
end
