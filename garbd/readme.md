Garbd được cài trên 1 node khác. có thể kết nối tới cluster. thường được cài trên load balancer.
cluster nhìn garbd như 1 node mariadb -> 2 node thành 3 node
giải quyết split-brain
Thực hiện trên ubuntu 14.04

Lưu ý đã có hệ thống 2 node mariadb galera
File cấu hình cluster.cnf có option sau


#Cài đặt 
##Add repo

`apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A`

```

cat << EOF > /etc/apt/sources.list.d/mariadb.list
deb http://repo.percona.com/apt trusty main
deb-src http://repo.percona.com/apt trusty main
EOF

```

Chạy update repo

`apt-get update`

Cài đặt garbd

`apt-get install  percona-xtradb-cluster-garbd-3.x`

Tạo file cấu hình tại đường dẫn  `/etc/default/garbd` có nội dung sau

`wsrep_cluster_address="gcomm://10.10.10.11,10.10.10.12?pc.wait_prim=no"`

```

# Copyright (C) 2012 Coedership Oy
# This config file is to be sourced by garb service script.

# A space-separated list of node addresses (address[:port]) in the cluster
GALERA_NODES="10.10.10.11:4567 10.10.10.12:4567"

# Galera cluster name, should be the same as on the rest of the nodes.
GALERA_GROUP="test_cluster"

# Optional Galera internal options string (e.g. SSL settings)
# see http://www.codership.com/wiki/doku.php?id=galera_parameters
GALERA_OPTIONS="pc.wait_prim=no"

# Log file for garbd. Optional, by default logs to syslog
LOG_FILE="/var/log/garbd.log"

```

Start garbd như 1 dịch vụ

`service garbd start`

hoặc chạy lệnh sau

`garbd -a gcomm://10.10.10.11:4567,10.10.10.12:4567?pc.wait_prim=no -g test_cluster`
