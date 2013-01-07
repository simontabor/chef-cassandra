# Cookbook Name:: cassandra
include_recipe "cassandra::cloud"
include_recipe "cassandra::create_seed_list"
include_recipe "cassandra::token_generation"


execute 'bash -c "ulimit -n 32768"'
execute 'echo "* soft nofile 32768" | sudo tee -a /etc/security/limits.conf'
execute 'echo "* hard nofile 32768" | sudo tee -a /etc/security/limits.conf'
execute 'echo "* soft memlock unlimited" | sudo tee -a /etc/security/limits.conf'
execute 'echo "* hard memlock unlimited" | sudo tee -a /etc/security/limits.conf'
execute 'sync'
execute 'echo 3 > /proc/sys/vm/drop_caches'


bash "Add hosts entry" do
  code <<-EOH
    if [ `grep #{ node[:cassandra][:ip_address] } /etc/hosts | wc -l` = 0 ]
    then
      chattr -i /etc/hosts
      echo #{ node[:cassandra][:ip_address] } `hostname` >> /etc/hosts
    fi
  EOH
end

# Create Cassandra User
user "#{ node[:cassandra][:user] }" do
  comment "Cassandra User"
  home "/home/#{ node[:cassandra][:user] }"
  shell "/bin/bash"
end

# Download Cassandra from Apache

remote_file "#{ node[:cassandra][:download_path]}/apache-cassandra-#{ node[:cassandra][:version] }-bin.tar.gz" do
  source "#{ node[:cassandra][:download_url_base] }/#{ node[:cassandra][:version] }/apache-cassandra-#{ node[:cassandra][:version] }-bin.tar.gz"
  mode "0644"
  checksum node[:cassandra][:checksum]
end

directory "#{ node[:cassandra][:data_file_directories]}" do
  owner "#{ node[:cassandra][:user] }"
  group "#{ node[:cassandra][:group] }"
  mode "0755"
  action :create
  recursive true
end

directory "#{ node[:cassandra][:commitlog_directory]}" do
  owner "#{ node[:cassandra][:user] }"
  group "#{ node[:cassandra][:group] }"
  mode "0755"
  action :create
  recursive true
end

directory "#{ node[:cassandra][:saved_caches_directory]}" do
  owner "#{ node[:cassandra][:user] }"
  group "#{ node[:cassandra][:group] }"
  mode "0755"
  action :create
  recursive true
end

directory "#{ node[:cassandra][:log_path]}" do
  owner "#{ node[:cassandra][:user] }"
  group "#{ node[:cassandra][:group] }"
  mode "0755"
  action :create
  recursive true
end


directory "/home/#{ node[:cassandra][:user] }" do
  owner "#{ node[:cassandra][:user] }"
  group "#{ node[:cassandra][:group] }"
  mode "0755"
  action :create
end

# Install Cassandra
bash "Unpack Cassandra" do
  code <<-EOH
    if [ ! -d #{ node[:cassandra][:install_path] }/apache-cassandra-#{ node[:cassandra][:version] } ]
    then
      cd #{ node[:cassandra][:install_path] }
      tar xzf #{ node[:cassandra][:download_path]}/apache-cassandra-#{ node[:cassandra][:version] }-bin.tar.gz
      ln -s #{ node[:cassandra][:install_path] }/apache-cassandra-#{ node[:cassandra][:version] } cassandra
    fi
  EOH
end

# Download jna.jar
remote_file "#{ node[:cassandra][:install_path] }/cassandra/lib/jna.jar" do
  source "http://repo1.maven.org/maven2/net/java/dev/jna/jna/#{ node[:cassandra][:jna_version] }/jna-#{ node[:cassandra][:jna_version] }.jar"
  mode "0644"
end

# Install startup script from template
template "/etc/init.d/cassandra" do
  source "cassandra.erb"
  owner "root"
  group "root"
  mode "0755"
end
      
# Deifne cassandra as a service.
service "cassandra" do
  supports :status => true, :start => true, :stop => true, :restart => true, :reload => true
end

# Configure cassandra.yaml
#   Copy cassandra.yaml template
template "#{node[:cassandra][:install_path]}/cassandra/conf/cassandra.yaml" do
  source "cassandra.yaml.erb"
  owner node[:cassandra][:user]
  group node[:cassandra][:group]
  mode "0644"
#  notifies :restart , resources(:service => "cassandra")
end

      
# Copy cassandra-env.sh template
template "#{node[:cassandra][:install_path]}/cassandra/conf/cassandra-env.sh" do
  source "cassandra-env.sh.erb"
  owner node[:cassandra][:user]
  group node[:cassandra][:group]
  mode "0755"
#  notifies :restart , resources(:service => "cassandra")
end

# Copy log4j-server.properties template
template "#{node[:cassandra][:install_path]}/cassandra/conf/log4j-server.properties" do
  source "log4j-server.properties.erb"
  owner node[:cassandra][:user]
  group node[:cassandra][:group]
  mode "0644"
#  notifies :restart , resources(:service => "cassandra")
end


# Start Cassandra
service "cassandra" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
