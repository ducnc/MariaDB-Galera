#!/bin/bash -ex

#ENV VAR
MYSQL1_IP=172.16.79.56
MYSQL2_IP=172.16.79.57
MYSQL3_IP=172.16.79.58
MY_NODE_NAME=mysql-03
MY_IP=$MYSQL3_IP
MYSQL_PASS='a'

#Install
sudo apt-get update -y
sudo apt-get -y install python-software-properties
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository 'deb http://mirrors.syringanetworks.net/mariadb/repo/5.5/ubuntu precise main'

apt-get update
echo mysql-server mysql-server/root_password password $MYSQL_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_PASS | debconf-set-selections
apt-get install -y mariadb-galera-server galera rsync 

cat << EOF > /etc/mysql/conf.d/cluster.cnf
[mysqld]
query_cache_size=0
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
query_cache_type=0
bind-address=0.0.0.0

# Galera Provider Configuration
wsrep_provider=/usr/lib/galera/libgalera_smm.so
#wsrep_provider_options="gcache.size=32G"

# Galera Cluster Configuration
wsrep_cluster_name="test_cluster"
wsrep_cluster_address="gcomm://$MYSQL1_IP,$MYSQL2_IP,$MYSQL3_IP"

# Galera Synchronization Congifuration
wsrep_sst_method=rsync
#wsrep_sst_auth=user:pass

# Galera Node Configuration
wsrep_node_address="$MY_IP"
wsrep_node_name="$MY_NODE_NAME"

EOF

service mysql stop
mv /root/debian.cnf /etc/mysql/
service mysql start
