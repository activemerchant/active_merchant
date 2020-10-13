##
# Fake response for dealing with file:/// requests

class Mechanize::FileResponse

  def initialize(file_path)
    @file_path = file_path
    @uri       = nil
  end

  def read_body
    raise Mechanize::ResponseCodeError.new(self) unless
      File.exist? @file_path

    if directory?
      yield dir_body
    else
      open @file_path, 'rb' do |io|
        yield io.read
      end
    end
  end

  def code
    File.exist?(@file_path) ? 200 : 404
  end

  def content_length
    return dir_body.length if directory?
    File.exist?(@file_path) ? File.stat(@file_path).size : 0
  end

  def each_header; end

  def [](key)
    return nil if key.casecmp('Content-Type') != 0
    return 'text/html' if directory?
    return 'text/html' if ['.html', '.xhtml'].any? { |extn|
      @file_path.end_with?(extn)
    }
    nil
  end

  def each
  end

  def get_fields(key)
    []
  end

  def http_version
    '0'
  end

  def message
    File.exist?(@file_path) ? 'OK' : 'Not Found'
  end

  def uri
    @uri ||= URI "file://#{@file_path}"
  end

  private

  def dir_body
    body = %w[<html><body>]
    body.concat Dir[File.join(@file_path, '*')].map { |f|
      "<a href=\"file://#{f}\">#{File.basename(f)}</a>"
    }
    body << %w[</body></html>]

    body.join("\n").force_encoding(Encoding::BINARY)
  end

  def directory?
    File.directory?(@file_path)
  end

end

