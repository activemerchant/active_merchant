##
# Raised when Mechanize detects the chunked transfer-encoding may be
# incorrectly terminated.

class Mechanize::ChunkedTerminationError < Mechanize::ResponseReadError
end

