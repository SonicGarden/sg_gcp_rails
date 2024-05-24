require 'em-websocket'
require 'pty'

class OneOffActivator
  CLOUD_SQL_PROXY_VERSION = 'v2.11.1'.freeze

  def initialize(port, auth_key)
    @port = port
    @auth_key = auth_key
    @cloud_sql_connection_name = ENV.fetch('CLOUD_SQL_CONNECTION_NAME')
    @connected = false

    @mutex = Mutex.new

    $stdout.sync = true
  end

  def activate
    launch_cloud_sql_proxy
    launch_websocket_server
  end

  private

  def launch_cloud_sql_proxy
    puts "Launch cloud sql proxy... connection_name: #{@cloud_sql_connection_name}"

    `curl -s -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/#{CLOUD_SQL_PROXY_VERSION}/cloud-sql-proxy.linux.amd64`
    `chmod +x cloud-sql-proxy`
    `mkdir /cloudsql; chmod 777 /cloudsql`
    spawn("./cloud-sql-proxy --unix-socket /cloudsql #{@cloud_sql_connection_name}")
  end

  def authorized?(handshake)
    handshake.headers['Sec-WebSocket-Protocol'] == @auth_key
  end

  def launch_websocket_server
    puts "Launch websocket server... port: #{@port}"

    EventMachine.run do
      EventMachine::WebSocket.start(host: "0.0.0.0", port: @port) do |ws|
        ws.onopen do |handshake|
          puts "Connected from #{ws.remote_ip}."

          @mutex.synchronize do
            authorized = authorized?(handshake)
            if authorized && !@connected
              @connected = true

              pty, slave = PTY.open
              pid = spawn(
                {'TERM' => 'xterm-256color'},
                '/bin/bash',
                in: slave, out: slave, err: slave
              )
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
                puts "Connection closed."

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
              puts "Connection refused. authorized: #{authorized}, connected: #{@connected}"

              ws.close_connection
            end
          end
        end
      end
    end
  end
end