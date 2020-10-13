##
# A credential store for HTTP authentication.
#
#   uri = URI 'http://example'
#
#   store = Mechanize::HTTP::AuthStore.new
#   store.add_auth uri, 'user1', 'pass'
#   store.add_auth uri, 'user2', 'pass', 'realm'
#
#   user, pass = store.credentials_for uri, 'realm' #=> 'user2', 'pass'
#   user, pass = store.credentials_for uri, 'other' #=> 'user1', 'pass'
#
#   store.remove_auth uri # removes all credentials

class Mechanize::HTTP::AuthStore

  attr_reader :auth_accounts # :nodoc:

  attr_reader :default_auth # :nodoc:

  ##
  # Creates a new AuthStore

  def initialize
    @auth_accounts = Hash.new do |h, uri|
      h[uri] = {}
    end

    @default_auth = nil
  end

  ##
  # Adds credentials +user+, +pass+ for the server at +uri+.  If +realm+ is
  # set the credentials are used only for that realm.  If +realm+ is not set
  # the credentials become the default for any realm on that URI.
  #
  # +domain+ and +realm+ are exclusive as NTLM does not follow RFC
  # 2617.  If +domain+ is given it is only used for NTLM authentication.

  def add_auth uri, user, pass, realm = nil, domain = nil
    uri = URI uri unless URI === uri

    raise ArgumentError,
          'NTLM domain given with realm which NTLM does not use' if
      realm and domain

    uri += '/'

    auth_accounts[uri][realm] = [user, pass, domain]

    self
  end

  ##
  # USE OF add_default_auth IS NOT RECOMMENDED AS IT MAY EXPOSE PASSWORDS TO
  # THIRD PARTIES
  #
  # Adds credentials +user+, +pass+ as the default authentication credentials.
  # If no other credentials are available  these will be returned from
  # credentials_for.
  #
  # If +domain+ is given it is only used for NTLM authentication.

  def add_default_auth user, pass, domain = nil
    warn <<-WARN
You have supplied default authentication credentials that apply to ANY SERVER.
Your username and password can be retrieved by ANY SERVER using Basic
authentication.

THIS EXPOSES YOUR USERNAME AND PASSWORD TO DISCLOSURE WITHOUT YOUR KNOWLEDGE.

Use add_auth to set authentication credentials that will only be delivered
only to a particular server you specify.
    WARN

    @default_auth = [user, pass, domain]
  end

  ##
  # Returns true if credentials exist for the +challenges+ from the server at
  # +uri+.

  def credentials? uri, challenges
    challenges.any? do |challenge|
      credentials_for uri, challenge.realm_name
    end
  end

  ##
  # Retrieves credentials for +realm+ on the server at +uri+.

  def credentials_for uri, realm
    uri = URI uri unless URI === uri

    uri += '/'
    uri.user = nil
    uri.password = nil

    realms = @auth_accounts[uri]

    realms[realm] || realms[nil] || @default_auth
  end

  ##
  # Removes credentials for +realm+ on the server at +uri+.  If +realm+ is not
  # set all credentials for the server at +uri+ are removed.

  def remove_auth uri, realm = nil
    uri = URI uri unless URI === uri

    uri += '/'

    if realm then
      auth_accounts[uri].delete realm
    else
      auth_accounts.delete uri
    end

    self
  end

end

