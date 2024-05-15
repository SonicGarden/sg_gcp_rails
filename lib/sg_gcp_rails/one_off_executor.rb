require 'em-websocket'
require 'pty'

class OneOffExecutor
  def initialize(port, auth_key)
    @port = port
    @auth_key = auth_key
    @current_connections = 0
  end

  def run
    puts "Starting one-off instance... port: #{@port}"

    EventMachine.run do
      EventMachine::WebSocket.start(host: "0.0.0.0", port: @port) do |ws|
        ws.onopen do |handshake|
          if authorized?(handshake) && @current_connections == 0
            @current_connections += 1

            # ENV['TERM'] = 'xterm-256color'
            pty, slave = PTY.open
            pid = spawn('bash -i', in: slave, out: slave, err: slave)
            slave.close

            # ptyとwebsocketの間でデータをやり取りするためのスレッド
            Thread.new do
              begin
                pty.each_char { |c| ws.send c }
              rescue => e
                puts "Error reading from pty: #{e} #{e.class}"
              end
            end

            # spawnで起動したプロセスが終了した場合の後片付け用のスレッド
            Thread.new do
              Process.waitpid(pid)

              # すぐに pty や websocket を close すると xterm 側が中途半端で閉じてしまうので、2秒ほど待つ
              sleep 2

              pty.close
              ws.close_connection
            end

            ws.onmessage do |cmd|
              begin
                pty.write cmd
                pty.flush
              rescue IOError => e
                puts "Error writing to pty: #{e.message}"
              end
            end

            ws.onclose do
              puts "WebSocket closed"

              begin
                Process.kill "KILL", pid
              rescue Errno::ESRCH
                # プロセスが既に終了している場合は何もしない
              end

              # 念のため 2 秒ほど待つ
              sleep 2

              pty.close
              EventMachine.stop
            end
          else
            puts "Unauthorized access from #{ws.remote_ip}"

            ws.close_connection
          end
        end
      end
    end
  end

  private

  def authorized?(handshake)
    handshake.headers['Sec-WebSocket-Protocol'] == @auth_key
  end
end