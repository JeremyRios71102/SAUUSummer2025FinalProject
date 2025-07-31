The my.cnf file is a template file for the my.cnf file you must add onto your install instance of mysql at mysql/conf/my.cnf. Here's what you should change on your end.
Bind-address
server_id
loose-group_replication_group_name
The number in db and port number in loose-group_replication_local_address
The port number in loose-group_replication_group_seeds