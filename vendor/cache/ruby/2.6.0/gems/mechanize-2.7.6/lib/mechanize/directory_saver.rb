##
# Unlike Mechanize::FileSaver, the directory saver places all downloaded files
# in a single pre-specified directory.
#
# You must register the directory to save to before using the directory saver:
#
#   agent.pluggable_parser['image'] = \
#     Mechanize::DirectorySaver.save_to 'images'

class Mechanize::DirectorySaver < Mechanize::Download

  @directory = nil
  @options = {}

  ##
  # Creates a DirectorySaver subclass that will save responses to the given
  # +directory+. If +options+ includes a +decode_filename+ value set to +true+
  # then the downloaded filename will be ran through +CGI.unescape+ before
  # being saved. If +options+ includes a +overwrite+ value set to +true+ then
  # downloaded file will be overwritten if two files with the same names exist.

  def self.save_to directory, options = {}
    directory = File.expand_path directory

    Class.new self do |klass|
      klass.instance_variable_set :@directory, directory
      klass.instance_variable_set :@options, options
    end
  end

  ##
  # The directory downloaded files will be saved to.

  def self.directory
    @directory
  end

  ##
  # True if downloaded files should have their names decoded before saving.

  def self.decode_filename?
    @options[:decode_filename]
  end

  ##
  # Checks if +overwrite+ parameter is set to true

  def self.overwrite?
    @options[:overwrite]
  end

  ##
  # Saves the +body_io+ into the directory specified for this DirectorySaver
  # by save_to.  The filename is chosen by Mechanize::Parser#extract_filename.

  def initialize uri = nil, response = nil, body_io = nil, code = nil
    directory = self.class.directory

    raise Mechanize::Error,
      'no save directory specified - ' \
      'use Mechanize::DirectorySaver.save_to ' \
      'and register the resulting class' unless directory

    super

    @filename = CGI.unescape(@filename) if self.class.decode_filename?
    path = File.join directory, @filename

    if self.class.overwrite?
      save! path
    else
      save path
    end
  end

end

