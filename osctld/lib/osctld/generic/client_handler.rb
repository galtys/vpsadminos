module OsCtld
  # Generic client handler for {Generic::Server}
  #
  # This class cannot be used directly, you need to subclass it and implement
  # template methods that will provide your logic. This class implements only
  # the generic communication protocol.
  #
  # == Protocol
  # The protocol is line-based, each line containing a JSON formatted message.
  # Client with the server can negoatiate a different protocol and hijack
  # the socket, e.g. this is used when the client is attaching a console
  # or executing command within a container.
  #
  # Upon connection, the server sends the client its version, if the server
  # implementation provides it:
  #
  #     {version: "version"}
  #
  # The client may decide to close the connection when an unsupported version
  # is detected.
  #
  # When the version is accepted, the client sends a command:
  #
  #     {cmd: <command>, opts: <command parameters>}
  #
  # The client waits for the server to reply, which can be one of:
  #
  #     {status: true, response: <command response>}
  #     {status: false, message: "error message"}
  #
  # Based on the response, the client either exits, sends another command, or
  # the connection can be hijacked and another communication protocol may be
  # used.
  class Generic::ClientHandler
    include Utils::Log

    attr_reader :opts

    def initialize(socket, opts)
      @sock = socket
      @opts = opts
    end

    def communicate
      v = server_version
      send_data({version: v}) if v

      loop do
        buf = ""

        while m = @sock.recv(1024)
          buf = buf + m
          break if m.empty? || m.end_with?("\n")
        end

        break if buf.empty?
        break if parse(buf) == :handled
      end

    rescue Errno::ECONNRESET
      # pass
    end

    # Return the server version that is sent to the client in the first message.
    # By default, no version is sent to the client.
    # @return [String]
    def server_version
      nil
    end

    # Handle client command and return a response or an error.
    #
    # Use return {#ok}, {#error}, {#error!} to return response, or report
    # error.
    #
    # @param req [Hash] client request
    # @return [{status: true, output: any}]
    # @return [{status: false, message: String}]
    # @return [{status: :handled}]
    def handle_cmd(req)
      raise NotImplementedError
    end

    # Signal command success, send `output` to the client
    def ok(output = nil)
      {status: true, output: output}
    end

    # Signal error `msg`
    def error(msg)
      {status: false, message: msg}
    end

    # Signal error `msg`, raises an exception
    def error!(msg)
      raise CommandFailed, msg
    end

    def socket
      @sock
    end

    protected
    def parse(data)
      begin
        req = JSON.parse(data, symbolize_names: true)

      rescue TypeError, JSON::ParserError
        return error('syntax error, expected a valid JSON')
      end

      log(:debug, self, "Received command '#{req[:cmd]}'")

      begin
        ret = handle_cmd(req)

        if !ret.is_a?(Hash)
          log(:fatal, self, "Unrecognized return value #{ret.class}, expected Hash")
          reply_error('internal error')
          return
        end

        if ret[:status] === true
          reply_ok(ret[:output])

        elsif ret[:status] === :handled
          log(:debug, self, 'Connection hijacked')
          return :handled

        elsif !ret[:message]
          log(:fatal, self, 'Command failed, but no error message provided')
          reply_error('internal error')

        else
          reply_error(ret[:message])
        end

      rescue CommandFailed => e
        reply_error(e.message)

      rescue => err
        log(:fatal, self, "Error during command execution: #{err.message}")
        log(:fatal, self, err.backtrace.join("\n"))
        reply_error('internal error')
      end

      true
    end

    def reply_error(err)
      send_data({status: false, message: err})
    end

    def reply_ok(res)
      send_data({status: true, response: res})
    end

    def send_data(data)
      @sock.send(data.to_json + "\n", 0)

    rescue Errno::EPIPE
    end
  end
end