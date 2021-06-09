# !/usr/bin/env ruby
#:include:../../README.rdoc
#:title:Ruby GSM
#--
# vim: noet
#++

# standard library
require 'timeout.rb'
require 'date.rb'

# gems (we're using the ruby-serialport gem
# now, so we can depend upon it in our spec)
require 'rubygems'
require 'serialport'
require 'pdu_sms'
require 'time'
require 'logger'

module Gsm
  class Modem
    include Timeout

    attr_accessor :verbosity, :read_timeout
    attr_reader :device, :port, :self_phone_number

    def initialize(port = :auto, verbosity = :warn, baud = 9600, cmd_delay = 0.1)
      
      @device = SerialPort.new(port, baud, 8, 1, SerialPort::NONE)
      @port = port
      
      @cmd_delay = cmd_delay
      @verbosity = verbosity
      @locked_to = false

      # how long should we wait for the modem to
      # respond before raising a timeout error?
      @read_timeout = 10

      # how many times should we retry commands (after
      # they fail, or time out) before giving up?
      @retry_commands = 4

      # when the maximum number of retries is exceeded,
      # should the modem AT+CFUN (hard reset), or allow
      # the exception to propagate?
      @reset_on_failure = true

      # keep track of the depth which each
      # thread is indented in the log
      @log_indents = {}
      @log_indents.default = 0

      # to keep multi-part messages until
      # the last part is delivered
      @multipart = {}

      # start logging to file
      @logger = Logger.new("port_#{@port.scan(/\d/).join('')}.log")

      # to store incoming messages
      # until they're dealt with by
      # someone else, like a commander
      @incoming = []
      # initialize the modem; rubygsm is (supposed to be) robust enough to function
      # without these working (hence the "try_"), but they make different modems more
      # consistant, and the logs a bit more sane.
      try_command 'ATE0'      # echo off
      try_command 'AT+CMEE=1' # useful errors

      # switching to PDU mode (mode 0) is MANDATORY
      command 'AT+CMGF=0'

      # storing all messages on SIM card only
      command 'AT+CPMS="SM","SM","SM"'
    end

    private

    INCOMING_FMT = '%y/%m/%d,%H:%M:%S%Z'.freeze #:nodoc:
    CMGL_STATUS = 0 # to fetch unread messages in PDU mode

    def parse_incoming_timestamp(timestamp)
      # extract the weirdo quarter-hour timezone,
      # convert it into a regular hourly offset
      timestamp.sub!(/(\d+)$/) do |m|
        format('%02d', (m.to_i / 4))
      end

      # parse the timestamp, and attempt to re-align
      # it according to the timezone we extracted
      Date.strptime(timestamp, INCOMING_FMT)
    end

    def parse_incoming_sms!(lines)
      n = 0

      # iterate the lines like it's 1984
      # (because we're patching the array,
      # which is hard work for iterators)
      while n < lines.length

        # not a CMT string? ignore it
        unless lines && lines[n] && lines[n][0, 5] == '+CMT:'
          n += 1
          next
        end

        # since this line IS a CMT string (an incoming
        # SMS), parse it and store it to deal with later
        unless (m = lines[n].match(/^\+CMT: "(.+?)",.*?,"(.+?)".*?$/))

          # the CMT data couldn't be parsed, so scrap it
          # and move on to the next line.  we'll lose the
          # incoming message, but it's better than blowing up
          log "Couldn't parse CMT data: #{lines[n]}", :warn
          lines.slice!(n, 2)
          n -= 1
          next
        end

        # extract the meta-info from the CMT line,
        # and the message from the FOLLOWING line
        from = *m.captures
        msg_text = lines[n + 1].strip

        # notify the network that we accepted
        # the incoming message (for read receipt)
        # BEFORE pushing it to the incoming queue
        # (to avoid really ugly race condition if
        # the message is grabbed from the queue
        # and responded to quickly, before we get
        # a chance to issue at+cnma)
        begin
          command 'AT+CNMA'

        # not terribly important if it
        # fails, even though it shouldn't
        rescue Gsm::Error
          log 'Receipt acknowledgement (CNMA) was rejected'
        end

        # we might abort if this part of a
        # multi-part message, but not the last
        catch :skip_processing do
          # multi-part messages begin with ASCII char 130
          if (msg_text[0] == 130) && (msg_text[1].chr == '@')
            text = msg_text[7, 999]

            # ensure we have a place for the incoming
            # message part to live as they are delivered
            @multipart[from] = [] unless @multipart.key?(from)

            # append THIS PART
            @multipart[from].push(text)

            # add useless message to log
            part = @multipart[from].length
            log "Received part #{part} of message from: #{from}"

            # abort if this is not the last part
            throw :skip_processing unless msg_text[5] == 173

            # last part, so switch out the received
            # part with the whole message, to be processed
            # below (the sender and timestamp are the same
            # for all parts, so no change needed there)
            msg_text = @multipart[from].join('')
            @multipart.delete(from)
          end

          # just in case it wasn't already obvious...
          log "Received message from #{from}: #{msg_text.inspect}"

          # store the incoming data to be picked up
          # from the attr_accessor as a tuple (this
          # is kind of ghetto, and WILL change later)
          # sent = parse_incoming_timestamp(timestamp)
          # msg = Gsm::Incoming.new(self, from, sent, msg_text)
          # @incoming.push(msg)
        end

        # drop the two CMT lines (meta-info and message),
        # and patch the index to hit the next unchecked
        # line during the next iteration
        lines.slice!(n, 2)
        n -= 1
      end
    end

    # write a string to the modem immediately,
    # without waiting for the lock
    def write(str)
      log "Write: #{str.inspect}", :traffic

      begin
        str.each_byte do |b|
          @device.putc(b.chr)
        end

      # the device couldn't be written to,
      # which probably means that it has
      # crashed or been unplugged
      rescue Errno::EIO
        raise Gsm::WriteError
      end
    end

    # read from the modem (blocking) until
    # the term character is hit, and return
    def read(term = nil)
      term = "\r\n" if term.nil?
      term = [term] unless term.is_a? Array
      buf = ''

      # include the terminator in the traffic dump,
      # if it's anything other than the default
      # suffix = (term != ["\r\n"]) ? " (term=#{term.inspect})" : ""
      # @logger.info "Read" + suffix, :traffic

      begin
        timeout(@read_timeout) do
          loop do
            char = @device.getc

            # die if we couldn't read
            # (nil signifies an error)
            raise Gsm::ReadError if char.nil?

            # append the character to the tmp buffer
            buf << char

            # if a terminator was just received,
            # then return the current buffer
            term.each do |t|
              len = t.length
              if buf[-len, len] == t
                log "Read: #{buf.inspect}", :traffic
                return buf.strip
              end
            end
          end
        end

      # reading took too long, so intercept
      # and raise a more specific exception
      rescue Timeout::Error
        log 'Read: Timed out', :warn
        raise TimeoutError
      end
    end

    def command(cmd, *args)
      tries = 0
      out = []

      begin
        # attempt to issue the command, which
        # might blow up, if the modem is angry
        @logger.info "Command: #{cmd} (##{tries + 1} of #{@retry_commands + 1})"
        out = command!(cmd, *args)
      rescue StandardError => err
        @logger.info "Rescued (in #command): #{err}"

        if (tries += 1) <= @retry_commands
          delay = (2**tries) / 2

          log "Sleeping for #{delay}"
          sleep(delay)
          retry
        end

        # when things just won't work, reboot the modem,
        # then try again. if the reboot fails, there is
        # nothing that we can do; so propagate
        # reboot the modem. this happens more often
        if @reset_on_failure
          @logger.info 'Resetting the modem'
          retry if reset!

          # failed to reboot :'(
          log "Couldn't reset"

        else
          # we've retried enough times, but don't
          # want to auto reset. let's hope that
          # someone upstream has a better idea
          @logger.info 'Propagating exception'
        end
        raise
      end

      # the command was successful
      @logger.info "=#{out.inspect} // command"
      out
    end

    # issue a single command, and wait for the response. if the command
    # fails (CMS or CME error is returned by the modem), a Gsm::Error
    # will be raised, and allowed to propagate. see Modem#command to
    # automatically retry failing commands
    def command!(cmd, resp_term = nil, write_term = "\r")
      out = ''
      @logger.info "Command!: #{cmd}"

      exclusive do
        write(cmd + write_term)
        out = wait(resp_term)
      end

      # some hardware (my motorola phone) adds extra CRLFs
      # to some responses. i see no reason that we need them
      out.delete ''

      # for the time being, ignore any unsolicited
      # status messages. i can't seem to figure out
      # how to disable them (AT+WIND=0 doesn't work)
      out.delete_if do |line|
        (line[0, 6] == '+WIND:') || (line[0, 6] == '+CREG:') || (line[0, 7] == '+CGREG:')
      end

      # log the modified output
      @logger.info "=#{out.inspect} // command!"

      # rest up for a bit (modems are
      # slow, and get confused easily)
      sleep(@cmd_delay)
      out

    # if the 515 (please wait) error was thrown,
    # then automatically re-try the command after
    # a short delay. for others, propagate
    rescue Error => err
      @logger.info "Rescued (in #command!): #{err}"

      if (err.type == 'CMS') && (err.code == 515)
        sleep 2
        retry
      end

      @logger.info
      raise
    end

    # proxy a single command to #command, but catch any
    # Gsm::Error exceptions that are raised, and return
    # nil. This should be used to issue commands which
    # aren't vital - of which there are VERY FEW.
    def try_command(cmd, *args)
      @logger.info "Trying Command: #{cmd}"
      out = command(cmd, *args)
      @logger.info "=#{out.inspect} // try_command"
      out
    rescue Error => err
      @logger.info "Rescued (in #try_command): #{err}"
      nil
    end

    def query(cmd)
      @logger.info "Query: #{cmd}"
      out = command cmd

      # only very simple responses are supported
      # (on purpose!) here - [response, crlf, ok]
      if (out.length == 2) && (out[1] == 'OK')
        @logger.info "=#{out[0].inspect}"
        out[0]
      else
        err = "Invalid response: #{out.inspect}"
        raise err
      end
    end

    # just wait for a response, by reading
    # until an OK or ERROR terminator is hit
    def wait(term = nil)
      buffer = []
      @logger.info 'Waiting for response'

      loop do
        buf = read(term)
        buffer.push(buf)

        # some errors contain useful error codes,
        # so raise a proper error with a description
        if (m = buf.match(/^\+(CM[ES]) ERROR: (\d+)$/))
          @logger.info "!! Raising Gsm::Error #{Regexp.last_match(1)} #{Regexp.last_match(2)}"
          raise Error.new(*m.captures)
        end

        # some errors are not so useful :|
        if buf == 'ERROR'
          @logger.info '!! Raising Gsm::Error'
          raise Error
        end

        # most commands return OK upon success, except
        # for those which prompt for more data (CMGS)
        if (buf == 'OK') || (buf == '>')
          @logger.info "=#{buffer.inspect}"
          return buffer
        end

        # some commands DO NOT respond with OK,
        # even when they're successful, so check
        # for those exceptions manually
        if buf.match?(/^\+CPIN: (.+)$/)
          @logger.info "=#{buffer.inspect}"
          return buffer
        end
      end
    end

    def exclusive
      old_lock = nil

      begin
        # prevent other threads from issuing
        # commands TO THIS MODDEM while this
        # block is working. this does not lock
        # threads, just the gsm device
        if @locked_to && (@locked_to != Thread.current)
          log "Locked by #{@locked_to['name']}, waiting..."

          # wait for the modem to become available,
          # so we can issue commands from threads
          sleep 0.05 while @locked_to
        end

        # we got the lock!
        old_lock = @locked_to
        @locked_to = Thread.current
        @logger.info 'Got lock'

        # perform the command while
        # we have exclusive access
        # to the modem device
        yield

      # something went bang, which happens, but
      # just pass it on (after unlocking...)
      rescue Gsm::Error
        raise

      # no message, but always un-
      # indent subsequent log messages
      # and RELEASE THE LOCK
      ensure
        @locked_to = old_lock
        Thread.pass
        @logger.info
      end
    end

    public

    # call-seq:
    #   reset! => true or false
    #
    # Resets the modem software, or raises Gsm::ResetError.
    def reset!
      command!('AT+CFUN=1')

    # if the reset fails, we'll wrap the exception in
    # a Gsm::ResetError, so it can be caught upstream.
    # this usually indicates a serious problem.
    rescue StandardError
      raise ResetError
    end

    # call-seq:
    #   hardware => hash
    #
    # Returns a hash of containing information about the physical
    # modem. The contents of each value are entirely manufacturer
    # dependant, and vary wildly between devices.
    #
    #   modem.hardware => { :manufacturer => "Multitech".
    #                       :model        => "MTCBA-G-F4",
    #                       :revision     => "123456789",
    #                       :serial       => "ABCD" }
    def hardware
      {
        manufacturer: query('AT+CGMI'),
        model: query('AT+CGMM'),
        revision: query('AT+CGMR'),
        serial: query('AT+CGSN')
      }
    end

    # The values accepted and returned by the AT+WMBS
    # command, mapped to frequency bands, in MHz. Copied
    # directly from the MultiTech AT command-set reference
    BANDS = {
      0 => '850',
      1 => '900',
      2 => '1800',
      3 => '1900',
      4 => '850/1900',
      5 => '900E/1800',
      6 => '900E/1900'
    }.freeze

    # call-seq:
    #   bands_available => array
    #
    # Returns an array containing the bands supported by
    # the modem.
    def bands_available
      data = query('AT+WMBS=?')

      # wmbs data is returned as something like:
      #  +WMBS: (0,1,2,3,4,5,6),(0-1)
      #  +WMBS: (0,3,4),(0-1)
      # extract the numbers with a regex, and
      # iterate each to resolve it to a more
      # readable description
      if (m = data.match(/^\+WMBS: \(([\d,]+)\),/))
        m.captures[0].split(',').collect do |index|
          BANDS[index.to_i]
        end
      else
        # TODO: Recover from this exception
        err = "Not WMBS data: #{data.inspect}"
        raise err
      end
    end

    # call-seq:
    #   band => string
    #
    # Returns a string containing the band
    # currently selected for use by the modem.
    def band
      data = query('AT+WMBS?')
      if (m = data.match(/^\+WMBS: (\d+),/))
        BANDS[m.captures[0].to_i]
      else
        # TODO: Recover from this exception
        err = "Not WMBS data: #{data.inspect}"
        raise err
      end
    end

    BAND_AREAS = {
      usa: 4,
      africa: 5,
      europe: 5,
      asia: 5,
      mideast: 5
    }.freeze

    # call-seq:
    #   band=(_numeric_band_) => string
    #
    # Sets the band currently selected for use
    # by the modem, using either a literal band
    # number (passed directly to the modem, see
    # Gsm::Modem.Bands) or a named area from
    # Gsm::Modem.BandAreas:
    #
    #   m = Gsm::Modem.new
    #   m.band = :usa    => "850/1900"
    #   m.band = :africa => "900E/1800"
    #   m.band = :monkey => ArgumentError
    #
    # (Note that as usual, the United States of
    # America is wearing its ass backwards.)
    #
    # Raises ArgumentError if an unrecognized band was
    # given, or raises Gsm::Error if the modem does
    # not support the given band.
    def band=(new_band)
      # resolve named bands into numeric
      # (mhz values first, then band areas)
      unless new_band.is_a?(Numeric)

        if BANDS.value?(new_band.to_s)
          new_band = BANDS.index(new_band.to_s)

        elsif BAND_AREAS.key?(new_band.to_sym)
          new_band = BAND_AREAS[new_band.to_sym]

        else
          err = "Invalid band: #{new_band}"
          raise ArgumentError, err
        end
      end

      # set the band right now (second wmbs
      # argument is: 0=NEXT-BOOT, 1=NOW). if it
      # fails, allow Gsm::Error to propagate
      command("AT+WMBS=#{new_band},1")
    end

    # call-seq:
    #   pin_required? => true or false
    #
    # Returns true if the modem is waiting for a SIM PIN. Some SIM cards will refuse
    # to work until the correct four-digit PIN is provided via the _use_pin_ method.
    def pin_required?
      !command('AT+CPIN?').include?('+CPIN: READY')
    end

    # call-seq:
    #   use_pin(pin) => true or false
    #
    # Provide a SIM PIN to the modem, and return true if it was accepted.
    def use_pin(pin)
      # if the sim is already ready,
      # this method isn't necessary
      if pin_required?
        begin
          command "AT+CPIN=#{pin}"

        # if the command failed, then
        # the pin was not accepted
        rescue Gsm::Error
          return false
        end
      end

      # no error = SIM
      # PIN accepted!
      true
    end

    # call-seq:
    #   signal => fixnum or nil
    #
    # Returns an fixnum between 1 and 99, representing the current
    # signal strength of the GSM network, or nil if we don't know.
    def signal_strength
      data = query('AT+CSQ')
      if (m = data.match(/^\+CSQ: (\d+),/))

        # 99 represents "not known or not detectable",
        # but we'll use nil for that, since it's a bit
        # more ruby-ish to test for boolean equality
        csq = m.captures[0].to_i
        csq < 99 ? csq : nil

      else
        # TODO: Recover from this exception
        err = "Not CSQ data: #{data.inspect}"
        raise err
      end
    end

    # call-seq:
    #   wait_for_network
    #
    # Blocks until the signal strength indicates that the
    # device is active on the GSM network. It's a good idea
    # to call this before trying to send or receive anything.
    def wait_for_network
      # keep retrying until the
      # network comes up (if ever)
      until (csq = signal_strength)
        sleep 1
      end

      # return the last
      # signal strength
      csq
    end

    # call-seq:
    #   send_sms(message) => true or false
    #   send_sms(recipient, text) => true or false
    #
    # Sends an SMS message via _send_sms!_, but traps
    # any exceptions raised, and returns false instead.
    # Use this when you don't really care if the message
    # was sent, which is... never.
    def send_sms(*args)
      send_sms!(*args)
      true

    # something went wrong
    rescue Gsm::Error
      false
    end

    # call-seq:
    #   send_sms!(message) => true or raises Gsm::Error
    #   send_sms!(receipt, text) => true or raises Gsm::Error
    #
    # Sends an SMS message, and returns true if the network
    # accepted it for delivery. We currently can't handle read
    # receipts, so have no way of confirming delivery. If the
    # device or network rejects the message, a Gsm::Error is
    # raised containing (hopefully) information about what went
    # wrong.
    #
    # Note: the recipient is passed directly to the modem, which
    # in turn passes it straight to the SMSC (sms message center).
    # For maximum compatibility, use phone numbers in international
    # format, including the *plus* and *country code*.
    def send_sms!(*args)
      # extract values from Outgoing object.
      # for now, this does not offer anything
      # in addition to the recipient/text pair,
      # but provides an upgrade path for future
      # features (like FLASH and VALIDITY TIME)
      if args.length == 1 && args[0].is_a?(Gsm::Outgoing)
        to = args[0].recipient
        msg = args[0].text

      # the < v0.4 arguments. maybe
      # deprecate this one day
      elsif args.length == 2
        to, msg = *args

      else
        raise ArgumentError,
          'The Gsm::Modem#send_sms method accepts a single Gsm::Outgoing instance, or recipient and text strings'
      end

      # the number must be in the international
      # format for some SMSCs (notably, the one
      # i'm on right now) so maybe add a PLUS
      # to = "+#{to}" unless(to[0,1]=="+")

      # 1..9 is a special number which does notm
      # result in a real sms being sent (see inject.rb)
      if to == '+123456789'
        log "Not sending test message: #{msg}"
        return false
      end

      # block the receiving thread while
      # we're sending. it can take some time
      exclusive do
        tries = 0

        begin
          @logger.info "Sending SMS to #{to}: #{msg}"
          log "Attempt #{tries + 1} of #{@retry_commands}"

          # initiate the sms, and wait for either
          # the text prompt or an error message
          command! "AT+CMGS=\"#{to}\"", ["\r\n", '> ']

          # send the sms, and wait until
          # it is accepted or rejected
          write "#{msg}#{26.chr}"
          wait

        # if something went wrong, we are
        # be stuck in entry mode (which will
        # result in someone getting a bunch
        # of AT commands via sms!) so send
        # an escpae, to... escape
        rescue StandardError => err
          log "Rescued #{err}"
          write 27.chr

          if (tries += 1) < @retry_commands
            @logger.info
            sleep((2**tries) / 2)
            retry
          end

          # allow the error to propagate,
          # so the application can catch
          # it for more useful info
          raise
        ensure
          @logger.info
        end
      end

      # if no error was raised,
      # then the message was sent
      true
    end

    # call-seq:
    #   receive(callback_method, interval=5, join_thread=false)
    #
    # Starts a new thread, which polls the device every _interval_
    # seconds to capture incoming SMS and call _callback_method_
    # for each, and polls the device's internal storage for incoming
    # SMS that we weren't notified about (some modems don't support
    # that).
    #
    #   class Receiver
    #     def incoming(msg)
    #       puts "From #{msg.from} at #{msg.sent}:", msg.text
    #     end
    #   end
    #
    #   # create the instances,
    #   # and start receiving
    #   rcv = Receiver.new
    #   m = Gsm::Modem.new "/dev/ttyS0"
    #   m.receive rcv.method :incoming
    #
    #   # block until ctrl+c
    #   while(true) { sleep 2 }
    #
    # Note: New messages may arrive at any time, even if this method's
    # receiver thread isn't waiting to process them. They are not lost,
    # but cached in @incoming until this method is called.
    def receive(callback, interval = 5)
      # keep on receiving forever
      loop do
        command 'AT'

        # check for new messages lurking in the device's
        fetch_stored_messages

        # if there are any new incoming messages,
        # iterate, and pass each to the receiver
        # in the same format that they were built
        # back in _parse_incoming_sms!_
        unless @incoming.empty?
          @incoming.each do |msg|
            begin
              callback.call(msg)
            rescue StandardError => err
              log "Error in callback: #{err}"
            end
          end

          # we have dealt with all of the pending
          # messages. TODO: this is a ridiculous
          # race condition, and i fail at ruby
          @incoming.clear
        end

        # command('AT+CMGD=0,1') # remove all read messages (to prevent filling whole simcard memory)
        # more info: http://www.developershome.com/sms/readSmsByAtCommands.asp
        # re-poll every
        # five seconds
        sleep(interval)
      end
    end

    def fetch_stored_messages
      # fetch all/unread (see constant) messages
      lines = command("AT+CMGL=#{CMGL_STATUS}")
      n = 0

      # if the last line returned is OK
      # (and it SHOULD BE), remove it
      lines.pop if lines[-1] == 'OK'

      # keep on iterating the data we received,
      # until there's none left. if there were no
      # stored messages waiting, this done nothing!
      while n < lines.length

        # attempt to find the CMGL line (we're skipping
        # two lines at a time in this loop, so we will
        # always land at a CMGL line here) - they look like:
        #   +CMGL: 1,0,,39
        #   07911326040011F5240B911326880736F40000111081017362401654747A0E4ACF41F4329E0E6A97E7F3F0B90C8A01
        unless lines[n].match?(/^\+CMGL: (\d+?),(\d+?"),/)
          err = "Couldn't parse CMGL data: #{lines[n]}"
          log err
          raise err
        end

        # find the index of the next
        # CMGL line, or the end
        nn = n + 1
        nn += 1 until nn >= lines.length || lines[nn][0, 6] == '+CMGL:'

        # extract and parse PDU from the line just below the CMGL line
        pdu = lines[n + 1]
        decoded_pdu = PduDecoder.decode(pdu)
        from = decoded_pdu.from
        sent = decoded_pdu.sent
        text = decoded_pdu.text

        # log the incoming message
        log "Fetched #{message_type(decoded_pdu)} from #{from} sent #{sent}: #{text.inspect}"

        # store the incoming data to be picked up
        # from the attr_accessor as a tuple (this
        # is kind of ghetto, and WILL change later)
        # sent = parse_incoming_timestamp(timestamp)
        msg = Gsm::Incoming.new(self, decoded_pdu, pdu)
        @incoming.push(msg)

        # skip over the messge line(s),
        # on to the next CMGL line
        n = nn
      end
    end

    def message_type(decoded_pdu)
      decoded_pdu.complete? ? 'complete message' : "message part (#{part_data(decoded_pdu)})"
    end

    def part_data(decoded_pdu)
      "#{decoded_pdu.part_number} from #{decoded_pdu.number_of_parts} with id #{decoded_pdu.multipart_id}"
    end
  end
end
