require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    # @gateway = PaypalExpressRestGateway.new(fixtures(:paypal_certificate))
    @bearer_token = "Ad3tDTnAAINpRD577-xGh_Rqyyz5kKQGkKVe5ZGF9zRpvGhqgefvlYdfYxnoehEMGXDPJncTRbWe68qW:EBDHIuoWkpLXftdNSu_agIzEyc1Te5URa012dB295_ZobvRgkvNGJYVBna5BQkEpjdu_WmpRj-wOpaCN"
    @headers = { "Authorization": "Bearer #{ @bearer_token }", "Content-Type": "application/json" }

    @body = {
        individual_owners: [
            {
                names: [
                    {
                        prefix: "Mr.",
                        given_name: "John",
                        surname: "Doe",
                        middle_name: "Middle",
                        suffix: "Jr.",
                        full_name: "John Middle Doe Jr.",
                        type: "LEGAL"
                    }
                ],
                citizenship: "US",
                addresses: [
                    {
                        address_line_1: "One Washington Square",
                        address_line_2: "Apt 123",
                        admin_area_2: "San Jose",
                        admin_area_1: "CA",
                        postal_code: "95112",
                        country_code: "US",
                        type: "HOME"
                    }
                ],
                phones: [
                    {
                        country_code: "1",
                        national_number: "6692468839",
                        extension_number: "1234",
                        type: "MOBILE"
                    }
                ],
                birth_details: {
                    date_of_birth: "1955-12-29"
                },
                type: "PRIMARY"
            }
        ],
        business_entity: {
            business_type: {
                type: "INDIVIDUAL",
                subtype: "ASSO_TYPE_INCORPORATED"
            },
            business_industry: {
                category: "1004",
                mcc_code: "2025",
                subcategory: "8931"
            },
            business_incorporation: {
                incorporation_country_code: "US",
                incorporation_date: "1986-12-29"
            },
            names: [
                {
                    business_name: "Test Enterprise",
                    type: "LEGAL_NAME"
                }
            ],
            emails: [
                {
                    type: "CUSTOMER_SERVICE",
                    email: "customerservice@example.com"
                }
            ],
            website: "https://mystore.testenterprises.com",
            addresses: [
                {
                    address_line_1: "One Washington Square",
                    address_line_2: "Apt 123",
                    admin_area_2: "San Jose",
                    admin_area_1: "CA",
                    postal_code: "95112",
                    country_code: "US",
                    type: "WORK"
                }
            ],
            phones: [
                {
                    country_code: "1",
                    national_number: "6692478833",
                    extension_number: "1234",
                    type: "CUSTOMER_SERVICE"
                }
            ],
            beneficial_owners: {
                individual_beneficial_owners: [
                    {
                        names: [
                            {
                                prefix: "Mr.",
                                given_name: "John",
                                surname: "Doe",
                                middle_name: "Middle",
                                suffix: "Jr.",
                                full_name: "John Middle Doe Jr.",
                                type: "LEGAL"
                            }
                        ],
                        citizenship: "US",
                        addresses: [
                            {
                                address_line_1: "One Washington Square",
                                address_line_2: "Apt 123",
                                admin_area_2: "San Jose",
                                admin_area_1: "CA",
                                postal_code: "95112",
                                country_code: "US",
                                type: "HOME"
                            }
                        ],
                        phones: [
                            {
                                country_code: "1",
                                national_number: "6692468839",
                                extension_number: "1234",
                                type: "MOBILE"
                            }
                        ],
                        birth_details: {
                            date_of_birth: "1955-12-29"
                        },
                        percentage_of_ownership: "50"
                    }
                ],
                business_beneficial_owners: [
                    {
                        business_type: {
                            type: "INDIVIDUAL",
                            subtype: "ASSO_TYPE_INCORPORATED"
                        },
                        business_industry: {
                            category: "1004",
                            mcc_code: "2025",
                            subcategory: "8931"
                        },
                        business_incorporation: {
                            incorporation_country_code: "US",
                            incorporation_date: "1986-12-29"
                        },
                        names: [
                            {
                                business_name: "Test Enterprise",
                                type: "LEGAL_NAME"
                            }
                        ],
                        emails: [
                            {
                                type: "CUSTOMER_SERVICE",
                                email: "customerservice@example.com"
                            }
                        ],
                        website: "https://mystore.testenterprises.com",
                        addresses: [
                            {
                                address_line_1: "One Washington Square",
                                address_line_2: "Apt 123",
                                admin_area_2: "San Jose",
                                admin_area_1: "CA",
                                postal_code: "95112",
                                country_code: "US",
                                type: "WORK"
                            }
                        ],
                        phones: [
                            {
                                country_code: "1",
                                national_number: "6692478833",
                                extension_number: "1234",
                                type: "CUSTOMER_SERVICE"
                            }
                        ],
                        percentage_of_ownership: "50"
                    }
                ]
            },
            office_bearers: [
                {
                    names: [
                        {
                            prefix: "Mr.",
                            given_name: "John",
                            surname: "Doe",
                            middle_name: "Middle",
                            suffix: "Jr.",
                            full_name: "John Middle Doe Jr.",
                            type: "LEGAL"
                        }
                    ],
                    citizenship: "US",
                    addresses: [
                        {
                            address_line_1: "One Washington Square",
                            address_line_2: "Apt 123",
                            admin_area_2: "San Jose",
                            admin_area_1: "CA",
                            postal_code: "95112",
                            country_code: "US",
                            type: "HOME"
                        }
                    ],
                    phones: [
                        {
                            country_code: "1",
                            national_number: "6692468839",
                            extension_number: "1234",
                            type: "MOBILE"
                        }
                    ],
                    birth_details: {
                        date_of_birth: "1955-12-29"
                    },
                    role: "DIRECTOR"
                }
            ],
            annual_sales_volume_range: {
                minimum_amount: {
                    currency_code: "USD",
                    value: "10000"
                },
                maximum_amount: {
                    currency_code: "USD",
                    value: "50000"
                }
            },
            average_monthly_volume_range: {
                minimum_amount: {
                    currency_code: "USD",
                    value: "1000"
                },
                maximum_amount: {
                    currency_code: "USD",
                    value: "50000"
                }
            },
            purpose_code: "P0104"
        },
        email: "accountemail@example.com",
        preferred_language_code: "en-US",
        tracking_id: "testenterprices123122",
        partner_config_override: {
            partner_logo_url: "https://www.paypalobjects.com/webstatic/mktg/logo/pp_cc_mark_111x69.jpg",
            return_url: "https://testenterprises.com/merchantonboarded",
            return_url_description: "the url to return the merchant after the paypal onboarding process.",
            action_renewal_url: "https://testenterprises.com/renew-exprired-url",
            show_add_credit_card: true
        },
        operations: [
            {
                operation: "BANK_ADDITION"
            }
        ],
        financial_instruments: {
            banks: [
                {
                    nick_name: "Bank of America",
                    account_number: "123405668293",
                    account_type: "CHECKING",
                    currency_code: "USD",
                    identifiers: [
                        {
                            type: "ROUTING_NUMBER_1",
                            value: "123456789"
                        }
                    ]
                }
            ]
        },
        legal_consents: [
            {
                type: "SHARE_DATA_CONSENT",
                granted: true
            }
        ],
        products: [
            "EXPRESS_CHECKOUT"
        ]
    }
    @options = { headers: @headers, body: @body }
  end

  def test_set_customer_creation_as_partner_referrals
    paypal_customer = ActiveMerchant::Billing::PaypalCustomerGateway.new(@options)


    response = paypal_customer.register_partner({})
    assert response.success?
    assert response.test?
    assert !response.params['links'].blank?
  end

end
