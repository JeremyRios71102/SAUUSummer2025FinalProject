//Run with the command mysqlsh --js.
var cl = dba.getCluster();
if (!cl) {
	cl = dba.createCluster('ffCluster'); //Change cluster name if needed
}
cl.status();

//Change usernames and ports if needed
print('Adding db2...');
cl.addInstance('clusterAdmin@db2:3306', {recoveryMethod:'incremental'});

print('Adding db3...');
cl.addInstance('clusterAdmin@db3:3306', {recoveryMethod:'incremental'});

print('Setting single primary mode (default) and checking status...');
cl.status();
