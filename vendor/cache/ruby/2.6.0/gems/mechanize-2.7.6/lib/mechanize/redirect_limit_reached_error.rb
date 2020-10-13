##
# Raised when too many redirects are sent

class Mechanize::RedirectLimitReachedError < Mechanize::Error

  attr_reader :page
  attr_reader :redirects
  attr_reader :response_code

  def initialize page, redirects
    @page          = page
    @redirects     = redirects
    @response_code = page.code

    super "Redirect limit of #{redirects} reached"
  end

end

