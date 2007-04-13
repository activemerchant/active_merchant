#
# = uuid.rb - UUID generator
#
# Author:: Assaf Arkin  assaf@labnotes.org
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/Ruby/UuidGenerator
# Copyright:: Copyright (c) 2005,2006 Assaf Arkin
# License:: MIT and/or Creative Commons Attribution-ShareAlike


require 'thread'
require 'yaml'
require 'singleton'
require 'logger'



# == Generating UUIDs
#
# Call UUID.new to generate and return a new UUID. The method returns a string in one of three
# formats. The default format is 36 characters long, and contains the 32 hexadecimal octets and
# hyphens separating the various value parts. The <tt>:compact</tt> format omits the hyphens,
# while the <tt>:urn</tt> format adds the <tt>:urn:uuid</tt> prefix.
#
# For example:
#  10.times do
#    p UUID.new
#  end
#
# ---
# == UUIDs in Brief
#
# UUID (universally unique identifier) are guaranteed to be unique across time and space.
#
# A UUID is 128 bit long, and consists of a 60-bit time value, a 16-bit sequence number and
# a 48-bit node identifier.
#
# The time value is taken from the system clock, and is monotonically incrementing. However,
# since it is possible to set the system clock backward, a sequence number is added. The
# sequence number is incremented each time the UUID generator is started. The combination
# guarantees that identifiers created on the same machine are unique with a high degree of
# probability.
#
# Note that due to the structure of the UUID and the use of sequence number, there is no
# guarantee that UUID values themselves are monotonically incrementing. The UUID value
# cannot itself be used to sort based on order of creation.
#
# To guarantee that UUIDs are unique across all machines in the network, use the IEEE 802
# MAC address of the machine's network interface card as the node identifier. Network interface
# cards have unique MAC address that are 47-bit long (the last bit acts as a broadcast flag).
# Use +ipconfig+ (Windows), or +ifconfig+ (Unix) to find the MAC address (aka physical address)
# of a network card. It takes the form of six pairs of hexadecimal digits, separated by hypen or
# colon, e.g. '<tt>08-0E-46-21-4B-35</tt>'
#
# For more information see {RFC 4122}[http://www.ietf.org/rfc/rfc4122.txt].
#
# == Configuring the UUID generator
#
# The UUID generator requires a state file which maintains the MAC address and next sequence
# number to use. By default, the UUID generator will use the file <tt>uuid.state</tt> contained
# in the current directory, or in the installation directory.
#
# Use UUID.config to specify a different location for the UUID state file. If the UUID state file
# does not exist, you can create one manually, or use UUID.config with the options <tt>:sequence</tt>
# and <tt>:mac_addr</tt>.
#
# A UUID state file looks like:
#   ---
#   last_clock: "0x28227f76122d80"
#   mac_addr: 08-0E-46-21-4B-35
#   sequence: "0x1639"
#
#
#--
# === Time-based UUID
#
# The UUID specification prescribes the following format for representing UUIDs. Four octets encode
# the low field of the time stamp, two octects encode the middle field of the timestamp, and two
# octets encode the high field of the timestamp with the version number. Two octets encode the
# clock sequence number and six octets encode the unique node identifier.
#
# The timestamp is a 60 bit value holding UTC time as a count of 100 nanosecond intervals since
# October 15, 1582. UUIDs generated in this manner are guaranteed not to roll over until 3400 AD.
#
# The clock sequence is used to help avoid duplicates that could arise when the clock is set backward
# in time or if the node ID changes. Although the system clock is guaranteed to be monotonic, the
# system clock is not guaranteed to be monotonic across system failures. The UUID cannot be sure
# that no UUIDs were generated with timestamps larger than the current timestamp.
#
# If the clock sequence can be determined at initialization, it is incremented by one. The clock sequence
# MUST be originally (i.e. once in the lifetime of a system) initialized to a random number to minimize the
# correlation across systems. The initial value must not be correlated to the node identifier.
#
# The node identifier must be unique for each UUID generator. This is accomplished using the IEEE 802
# network card address. For systems with multiple IEEE 802 addresses, any available address can be used.
# For systems with no IEEE address, a 47 bit random value is used and the multicast bit is set so it will
# never conflict with addresses obtained from network cards.
#
# === UUID state file
#
# The UUID state is contained in the UUID state file. The file name can be specified when configuring
# the UUID generator with UUID.config. The default is to use the file +uuid.state+ in the current directory,
# or the installation directory.
#
# The UUID state file is read once when the UUID generator is first used (or configured). The sequence
# number contained in the UUID is read and used, and the state file is updated to the next sequence
# number. The MAC address is also read from the state file. The current clock time (in 100ns resolution)
# is stored in the state file whenever the sequence number is updated, but is never read.
#
# If the UUID generator detects that the system clock has been moved backwards, it will obtain a new
# sequence in the same manner. So it is possible that the UUID state file will be updated while the
# application is running.
#++
module UUID

  unless const_defined?(:VERSION)
    VERSION = '1.0.3'

    PACKAGE = "uuid"

    # Default state file.
    STATE_FILE = "uuid.state"

    # Clock multiplier. Converts Time (resolution: seconds) to UUID clock (resolution: 10ns)
    CLOCK_MULTIPLIER = 10000000 #:nodoc:

    # Clock gap is the number of ticks (resolution: 10ns) between two Ruby Time ticks.
    CLOCK_GAPS = 100000 #:nodoc:

    # Version number stamped into the UUID to identify it as time-based.
    VERSION_CLOCK = 0x0100 #:nodoc:

    # Formats supported by the UUID generator.
    FORMATS = {:compact=>"%08x%04x%04x%04x%012x", :default=>"%08x-%04x-%04x-%04x-%012x", :urn=>"urn:uuid:%08x-%04x-%04x-%04x-%012x"} #:nodoc:

    # Length (in characters) of UUIDs generated for each of the formats.
    FORMATS_LENGTHS = {:compact=>32, :default=>36, :urn=>45} #:nodoc:

    ERROR_INVALID_SEQUENCE = "Invalid sequence number: found '%s', expected 4 hexdecimal digits" #:nodoc:

    ERROR_NOT_A_SEQUENCE = "Not a sequence number: expected integer between 0 and 0xFFFF" #:nodoc:

    ERROR_INVALID_MAC_ADDR = "Invalid MAC address: found '%s', expected a number in the format XX-XX-XX-XX-XX-XX" #:nodoc:

    INFO_INITIALIZED = "Initialized UUID generator with sequence number 0x%04x and MAC address %s" #:nodoc:

    ERROR_INITIALIZED_RANDOM_1 = "Initialized UUID generator with random sequence number/MAC address." #:nodoc:

    ERROR_INITIALIZED_RANDOM_2 = "UUIDs are not guaranteed to be unique. Please create a uuid.state file as soon as possible." #:nodoc:

    IFCONFIG_PATTERN = /[^:\-](?:[0-9A-Za-z][0-9A-Za-z][:\-]){5}[0-9A-Za-z][0-9A-Za-z][^:\-]/ #:nodoc:


    # Regular expression to identify a 36 character UUID. Can be used for a partial match.
    REGEXP = /[[:xdigit:]]{8}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{12}/

    # Regular expression to identify a 36 character UUID. Can only be used for a full match.
    REGEXP_FULL = /^[[:xdigit:]]{8}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{12}$/
  end


  @@mutex       = Mutex.new
  @@last_clock  = nil
  @@logger      = nil
  @@state_file  = nil


  # Generates and returns a new UUID string.
  #
  # The argument +format+ specifies which formatting template to use:
  # * <tt>:default</tt> -- Produces 36 characters, including hyphens separating the UUID value parts
  # * <tt>:compact</tt> -- Produces a 32 digits (hexadecimal) value with no hyphens
  # * <tt>:urn</tt> -- Aadds the prefix <tt>urn:uuid:</tt> to the <tt>:default</tt> format
  #
  # For example:
  #  print UUID.new :default
  # or just
  #  print UUID.new
  #
  # :call-seq:
  #   UUID.new([format])  -> string
  #
  def new(format = nil)
    # Determine which format we're using for the UUID string.
    template = FORMATS[format || :default] or
        raise RuntimeError, "I don't know the format '#{format}'"

    # The clock must be monotonically increasing. The clock resolution is at best 100 ns
    # (UUID spec), but practically may be lower (on my setup, around 1ms). If this method
    # is called too fast, we don't have a monotonically increasing clock, so the solution is
    # to just wait.
    # It is possible for the clock to be adjusted backwards, in which case we would end up
    # blocking for a long time. When backward clock is detected, we prevent duplicates by
    # asking for a new sequence number and continue with the new clock.
    clock = @@mutex.synchronize do
      # Initialize UUID generator if not already initialized. Uninitizlied UUID generator has no
      # last known clock.
      next_sequence unless @@last_clock
      clock = (Time.new.to_f * CLOCK_MULTIPLIER).to_i & 0xFFFFFFFFFFFFFFF0
      if clock > @@last_clock
        @@drift = 0
        @@last_clock = clock
      elsif clock = @@last_clock
        drift = @@drift += 1
        if drift < 10000
          @@last_clock += 1
        else
          Thread.pass
          nil
        end
      else
        next_sequence
        @@last_clock = clock
      end
    end while not clock
    sprintf template, clock & 0xFFFFFFFF, (clock >> 32)& 0xFFFF, ((clock >> 48) & 0xFFFF | VERSION_CLOCK),
            @@sequence & 0xFFFF, @@mac_hex & 0xFFFFFFFFFFFF
  end


  alias uuid new
  module_function :uuid, :new


  # Configures the UUID generator. Use this method to specify the UUID state file, logger, etc.
  #
  # The method accepts the following options:
  # * <tt>:state_file</tt> -- Specifies the location of the state file. If missing, the default
  #   is <tt>uuid.state</tt>
  # * <tt>:logger<tt> -- The UUID generator will use this logger to report the state information (optional).
  # * <tt>:sequence</tt> -- Specifies the sequence number (0 to 0xFFFF) to use. Required to
  #   create a new state file, ignored if the state file already exists.
  # * <tt>:mac_addr</tt> -- Specifies the MAC address (xx-xx-xx-xx-xx) to use. Required to
  #   create a new state file, ignored if the state file already exists.
  #
  # For example, to create a new state file:
  #  UUID.config :state_file=>'my-uuid.state', :sequence=>rand(0x10000), :mac_addr=>'0C-0E-35-41-60-65'
  # To use an existing state file and log to +STDOUT+:
  #  UUID.config :state_file=>'my-uuid.state', :logger=>Logger.new(STDOUT)
  #
  # :call-seq:
  #   UUID.config(config)
  #
  def self.config(options)
    options ||= {}
    @@mutex.synchronize do
      @@logger = options[:logger]
      next_sequence options
    end
  end


  # Create a uuid.state file by finding the IEEE 802 NIC MAC address for this machine.
  # Works for UNIX (ifconfig) and Windows (ipconfig). Creates the uuid.state file in the
  # installation directory (typically the GEM's lib).
  def self.setup()
    file = File.expand_path(File.dirname(__FILE__))
    file = File.basename(file) == 'lib' ? file = File.join(file, '..', STATE_FILE) : file = File.join(file, STATE_FILE)
    file = File.expand_path(file)
    if File.exist? file
      puts "#{PACKAGE}: Found an existing UUID state file: #{file}"
    else
      puts "#{PACKAGE}: No UUID state file found, attempting to create one for you:"
      # Run ifconfig for UNIX, or ipconfig for Windows.
      config = ""
      Kernel.open "|ifconfig" do |input|
        input.each_line { |line| config << line }
      end rescue nil
      Kernel.open "|ipconfig /all" do |input|
        input.each_line { |line| config << line }
      end rescue nil

      addresses = config.scan(IFCONFIG_PATTERN).collect { |addr| addr[1..-2] }
      if addresses.empty?
        puts "Could not find any IEEE 802 NIC MAC addresses for this machine."
        puts "You need to create the uuid.state file manually."
      else
        puts "Found the following IEEE 802 NIC MAC addresses on your computer:"
        addresses.each { |addr| puts "  #{addr}" }
        puts "Selecting the first address #{addresses[0]} for use in your UUID state file."
        File.open file, "w" do |output|
          output.puts "mac_addr: \"#{addresses[0]}\""
          output.puts format("sequence: \"0x%04x\"", rand(0x10000))
        end
        puts "Created a new UUID state file: #{file}"
      end
    end
    file
  end


private

    def self.next_sequence(config = nil)
      # If called to advance the sequence number (config is nil), we have a state file that we're able to use.
      # If called from configuration, use the specified or default state file.
      state_file = (config && config[:state_file]) || @@state_file

      unless state_file
        if File.exist?(STATE_FILE)
          state_file = STATE_FILE
        else
          file = File.expand_path(File.dirname(__FILE__))
          file = File.basename(file) == 'lib' ? file = File.join(file, '..', STATE_FILE) : file = File.join(file, STATE_FILE)
          file = File.expand_path(file)
          state_file = File.exist?(file) ? file : setup
        end
      end
      begin
        File.open state_file, "r+" do |file|
          # Lock the file for exclusive access, just to make sure it's not being read while we're
          # updating its contents.
          file.flock(File::LOCK_EX)
          state = YAML::load file
          # Get the sequence number. Must be a valid 16-bit hexadecimal value.
          sequence = state['sequence']
          if sequence
            raise RuntimeError, format(ERROR_INVALID_SEQUENCE, sequence) unless
              sequence.is_a?(String) and sequence =~ /[0-9a-fA-F]{4}/
            sequence = sequence.hex & 0xFFFF
          else
            sequence = rand(0x10000)
          end
          # Get the MAC address. Must be 6 pairs of hexadecimal octets. Convert MAC address into
          # a 48-bit value with the higher bit being zero.
          mac_addr = state['mac_addr']
          raise RuntimeError, format(ERROR_INVALID_MAC_ADDR, mac_addr) unless
            mac_addr.is_a?(String) and mac_addr =~ /([0-9a-fA-F]{2}[:\-]){5}[0-9a-fA-F]{2}/
          mac_hex = mac_addr.scan(/[0-9a-fA-F]{2}/).join.hex & 0x7FFFFFFFFFFF

          # If everything is OK, proceed to the next step. Grab the sequence number and store
          # the new state. Start at beginning of file, and truncate file when done.
          @@mac_addr, @@mac_hex, @@sequence, @@state_file = mac_addr, mac_hex, sequence, state_file
          file.pos = 0
          dump file, true
          file.truncate file.pos
        end
        # Initialized.
        if @@logger
          @@logger.info format(INFO_INITIALIZED, @@sequence, @@mac_addr)
        else
          warn "#{PACKAGE}: " + format(INFO_INITIALIZED, @@sequence, @@mac_addr)
        end
        @@last_clock, @@drift = (Time.new.to_f * CLOCK_MULTIPLIER).to_i, 0
      rescue Errno::ENOENT=>error
        if !config
          # Generate random values.
          @@mac_hex, @@sequence, @@state_file = rand(0x800000000000) | 0xF00000000000, rand(0x10000), nil
          # Initialized.
          if @@logger
            @@logger.error ERROR_INITIALIZED_RANDOM_1
            @@logger.error ERROR_INITIALIZED_RANDOM_2
          else
            warn "#{PACKAGE}: " + ERROR_INITIALIZED_RANDOM_1
            warn "#{PACKAGE}: " + ERROR_INITIALIZED_RANDOM_2
          end
          @@last_clock, @@drift = (Time.new.to_f * CLOCK_MULTIPLIER).to_i, 0
        else
          # No state file. If we were called for configuration with valid sequence number and MAC address,
          # attempt to create state file. See code above for how we interpret these values.
          sequence = config[:sequence]
          raise RuntimeError, format(ERROR_NOT_A_SEQUENCE, sequence) unless sequence.is_a?(Integer)
          sequence &= 0xFFFF
          mac_addr = config[:mac_addr]
          raise RuntimeError, format(ERROR_INVALID_MAC_ADDR, mac_addr) unless
            mac_addr.is_a?(String) and mac_addr =~ /([0-9a-fA-F]{2}[:\-]){5}[0-9a-fA-F]{2}/
          mac_hex = mac_addr.scan(/[0-9a-fA-F]{2}/).join.hex & 0x7FFFFFFFFFFF
          File.open state_file, "w" do |file|
            file.flock(File::LOCK_EX)
            @@mac_addr, @@mac_hex, @@sequence, @@state_file = mac_addr, mac_hex, sequence, state_file
            file.pos = 0
            dump file, true
            file.truncate file.pos
          end
          # Initialized.
          if @@logger
            @@logger.info format(INFO_INITIALIZED, @@sequence, @@mac_addr)
          else
            warn "#{PACKAGE}: " + format(INFO_INITIALIZED, @@sequence, @@mac_addr)
          end
          @@last_clock, @@drift = (Time.new.to_f * CLOCK_MULTIPLIER).to_i, 0
        end
      rescue Exception=>error
        @@last_clock = nil
        raise error
      end
    end

    def self.dump(file, plus_one)
      # Gets around YAML weirdness, like ont storing the MAC address as a string.
      if @@sequence && @@mac_addr
        file.puts "mac_addr: \"#{@@mac_addr}\""
        file.puts "sequence: \"0x%04x\"" % ((plus_one ? @@sequence + 1 : @@sequence) & 0xFFFF)
        file.puts "last_clock: \"0x%x\"" % (@@last_clock || (Time.new.to_f * CLOCK_MULTIPLIER).to_i)
      end
    end

end


if defined?(ActiveRecord)
  class ActiveRecord::Base

      def self.uuid_primary_key()
        before_create { |record| record.id = UUID.new unless record.id }
      end

  end
end


if __FILE__ == $0
  UUID.setup
end
