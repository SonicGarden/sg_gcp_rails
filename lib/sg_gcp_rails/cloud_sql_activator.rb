class CloudSqlActivator
  def initialize(connection_name)
    @connection_name = connection_name
  end

  def run
    puts "Activate cloud sql... connection_name: #{@connection_name}"

    `curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.11.1/cloud-sql-proxy.linux.amd64`
    `chmod +x cloud-sql-proxy`
    `mkdir /cloudsql; chmod 777 /cloudsql`
    `./cloud-sql-proxy --unix-socket /cloudsql #{@connection_name} &`
  end
end