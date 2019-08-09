# vim: noet

module Gsm
  class Modem
    private

    # Symbols accepted by the Gsm::Modem.new _verbosity_
    # argument. Each level includes all of the levels
    # below it (ie. :debug includes all :warn messages)
    LOG_LEVELS = {
      file: 5,
      traffic: 4,
      debug: 3,
      warn: 2,
      error: 1
    }.freeze

    def log_init(path = Dir.pwd)
      if @port

        # build a log filename based on the device's
        # path (ttyS0, ttyUSB1, etc) and date/time
        fn_port = File.basename(@port)
        fn_time = Time.now.strftime('%Y-%m-%d.%H-%M-%S')
        filename = "#{fn_port}.modem_setup.#{fn_time}.log"

      # if the port path is unknown, log to
      # the same file each time. TODO: we
      # really need a proper logging solution
      else
        filename = 'modem_setup.log'
      end

      # Join path to file if present
      filename = File.join(path, filename) if path.present?

      # (re-) open the log file
      @log = File.new filename, 'w'

      # dump some useful information
      # at the top, for debugging
      log 'RUBYGSM'
      log "  port: #{@port}"
      log "  timeout: #{@read_timeout}"
      log "  verbosity: #{@verbosity}"
      log "  started at: #{Time.now}"
      log '===='
    end

    def add_self_phone_number_to_log_file_name(self_phone_number)
      new_name = File.absolute_path(@log).sub('modem_setup', self_phone_number)
      File.rename(@log, new_name)
    end

    def log(msg, level = :debug)
      # abort if logging isn't
      # enabled yet (or ever?)
      return false if @log.nil?

      ind = '  ' * ((@log_indents[Thread.current] || 0) + 1)

      # create a
      # thr = Thread.current["name"]
      # thr = (thr.nil?) ? "" : "[#{thr}] "
      # dump (almost) everything to file
      if LOG_LEVELS[level] >= (LOG_LEVELS[:debug]) || level == :file

        @log.puts Time.now.strftime('%F %T.%L') + ind + msg
        @log.flush
      end

      # also print to the rolling
      # screen log, if necessary
      if LOG_LEVELS[@verbosity] >= LOG_LEVELS[level]
        warn Time.now.strftime('%F %T.%L') + ind + msg
      end
    end

    # log a message, and increment future messages
    # in this thread. useful for nesting logic
    def log_incr(*args)
      log(*args) unless args.empty?
      @log_indents[Thread.current] += 1
    end

    # close the logical block, and (optionally) log
    def log_decr(*args)
      @log_indents[Thread.current] -= 1 if (@log_indents[Thread.current]).positive?
      log(*args) unless args.empty?
    end

    # the last message in a logical block
    def log_then_decr(*args)
      log(*args)
      log_decr
    end
  end
end
