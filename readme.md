#1. Giới thiệu
Khi giao dịch với hệ thống  CSDL trong môi trường sản xuất, nó thường là cách tốt nhất để có 1 số loại thủ tục nhân rộng. Replication (nhân rộng) cho phép dữ liệu của bạn sẽ được chuyển giao tới các node khác tự động 

Đơn giản là master-slave replication thường được dùng nhất trong SQl. Nó cho phép bạn sử dụng 1 "master" server để thực hiện các lệnh write của ứng dụng, và nhiều "slave" server có thể được sử dụng để đọc dữ liệu. Nó có thể được cấu hình failover và các kĩ thuật khác.

Khi master-slave replication hữu dụng, nó không linh hoạt như master-master replication. Ở 1 hệ thống master-master replication, mỗi node có thể chấp nhận đọc và phân tán chúng vào cluster. Mặc định MariaDB không có phiên bản ổn định kiểu này, nhưng một số patch được biết đến là "Galera "  để bổ sung master-master replication

Trong hướng dẫn này chúng ta sẽ tạo 1 Galera Cluster sử dụng Ubuntu 14.04. 
Chúng ta sẽ sử dụng 3 server để thực hiện (các cluster cấu hình nhỏ nhất) và 5 node được recommend cho production

Note: Tại sao ít nhất phải là 3 node mà không phải là 2?

Galera vẫn chạy trong 1 thiết lập 2 node. Tuy nhiên luôn luôn có 1 kịch bản split-brain. Ví dụ, giả sử bạn có DB1 và DB2 tạo thành 1 cluster galera. Nếu DB1 down , việc ghi và đọc sẽ thực hiện trên DB2. Và khi DB1 được khôi phục trở lại. Thời điểm này DB1 là backup, làm một IST (Incremental State Transfer chức năng mà tahy vì toàn bộ snapshot có thể bắt kịp với group bằng cách nhận các writeset chưa có nhưng chỉ khi writeset vẫn còn trong bộ nhớ casche của node khác). Và bạn sẽ thực hiện một SST đầy đủ từ DB2 (State Snapshot Transfer là một bản sao đầy đủ của dữ liệu từ một nút khác. Nó được sử dụng khi một nút join vào cluster, nó phải chuyern dữ liệu từ nút hiện có .) Dễ dàng nhất để làm điều này là delete galera cache file trước khi start DB1. Trong quá trình SST DB2 trong trạng thái read-only và không thể thực hiện các lệnh insert, update hoặc delete. Khi 3 node trong cluster, ít nhất 1 node có thể thực hiện insert, update và delete


#2. Cấu hình 

Chuẩn bị 3 server cài sẵn hệ điều hành Ubuntu 14.04


mô hình

<img src="http://i.imgur.com/ZgPP3Mz.png">

Thực hiện trên 3 node

##2.1. Add MariaDB Repo

```

sudo apt-get update
sudo apt-get install python-software-properties

```

Add key  MariaDB repo

```

apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository 'deb http://mirrors.syringanetworks.net/mariadb/repo/5.5/ubuntu precise main'

```


##2.2. Install MariaDB with Galera Patches

```

apt-get update
apt-get install mariadb-galera-server galera

```

Nếu chưa có rsync thì phải install rsync

`apt-get install rsync`


##2.3. Config


tạo file /etc/mysql/conf.d/cluster.cnf trên mỗi node với nội dung sau


```

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
wsrep_cluster_address="gcomm://first_ip,second_ip,third_ip"

# Galera Synchronization Congifuration
wsrep_sst_method=rsync
#wsrep_sst_auth=user:pass

# Galera Node Configuration
wsrep_node_address="this_node_ip"
wsrep_node_name="this_node_name"

```

- `first_ip` : IP node 1 :  `10.10.10.10`

- `second_ip` : IP node 2 :  `10.10.10.20`

- `third_ip` : IP node 3 : `10.10.10.30`

- `this_node_name` : tên của node đang cấu hình

- `this_node_ip` : IP của node đang cấu hình

Ví dụ trên node 1 file cluster.cnf là 


```

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
wsrep_cluster_address="gcomm://10.10.10.10,10.10.10.20,10.10.10.30"

# Galera Synchronization Congifuration
wsrep_sst_method=rsync
#wsrep_sst_auth=user:pass

# Galera Node Configuration
wsrep_node_address="10.10.10.10"
wsrep_node_name="node-1"

```

###Giải thích 

- Phần đầu tiên là cấu hình lại cài đặt của MariaDB/MySQL cho phép MySQL thực hiện chức năng đúng
- phần "Galera Provider Configuration " được sử dụng để cấu hình thành phần MariaDB cung cấp 1 API Writeset replication. Có nghĩa là Galera, Galera cung cấp wsrep (Writeset Replication)
- Phần "Galera Cluster Configuration" đinh nghĩa cluster mà chúng ta đang tạo. Nó định nghĩa các member bằng địa chỉ IP hoặc domain name và tên của cluster để chắc chắn member join đúng group
- Phần "Galera Synchronization Configuration" định nghĩa cluster sẽ giao tiếp và đồng bộ dữ liệu giữa các member như thế nào. Trong cấu hình này đơn giản ta sử dụng rsync
- Phần "Galera Node Configuration" được sử dụng để làm rõ địa  chỉ IP và tên của server đang cấu hình. Điều này hỗ trợ khi troubeshoot các vấn đề trong logs

##2.4. Copy cấu hình bảo trì Debian

Hiện tại. Ubuntu và máy chủ MariaDB Debian sử dụng 1 user bảo trì đặc biejn để bảo dưỡng định kì.

Với môi trường cluster của chúng ta được chia sẻ giữa các node, user bảo trì  tạo ra ngẫu nhiên thông tin đăng nhập trên mỗi node sẽ không thể thực hiện một lệnh chính xác. Chỉ có các máy chỉ ban đầu sẽ có các thông tin bảo trì đúng, ví những người khác sẽ cố gắng sử dụng thiết lập local để truy cập vào môi trường cluster.

Để làm điều này đơn giản là copy nội dung của file bảo trì tới mỗi node.

Trong mô hình lab của ta, copy nội dung file /etc/mysql/debian.cnf của node 1 tới node 2 và 3.

Nội dung của file đó như sau 

```

[client]
host     = localhost
user     = debian-sys-maint
password = 03P8rdlknkXr1upf
socket   = /var/run/mysqld/mysqld.sock
[mysql_upgrade]
host     = localhost
user     = debian-sys-maint
password = 03P8rdlknkXr1upf
socket   = /var/run/mysqld/mysqld.sock
basedir  = /usr

```


##2.5. Start cluster

Để bắt đầu ta cần stop dịch vụ MariaDB trên các node.

`service mysql stop`

Ta start node 1 với lệnh sau

`service mysql start --wsrep_new_cluster`

Tại 2 node còn lại ta start MariaDB

`service mysql start`

##2.6 Test Master-Master

Tạo database trên node 1 

`create database test;`

Hiển thị database trên node 2 và 3 ta thấy database test. Thực hiện trên node 2 và 3 có kết quả tương tự.

#3. Kết luận

Trong bài hướng dẫn này ta đã cấu hình được Galera Cluster. Điều này có thể giúp một chút để cân bằng tải trong các môi trường ứng dụng chuyên sâu
