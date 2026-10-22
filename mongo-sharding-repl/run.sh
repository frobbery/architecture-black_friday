cd "$(dirname "$0")"
docker compose up -d
sleep 10

docker exec configSrv mongosh --port 27017 --quiet --eval 'rs.initiate({_id:"config_server",configsvr:true,members:[{_id:0,host:"configSrv:27017"}]})'
docker exec shard1 mongosh --port 27018 --quiet --eval 'rs.initiate({_id:"shard1",members:[
{_id:0,host:"shard1:27018"},
{_id:1,host:"shard1-1:27021"},
{_id:2,host:"shard1-2:27022"}]})'
docker exec shard2 mongosh --port 27019 --quiet --eval 'rs.initiate({_id:"shard2",members:[
{_id:0,host:"shard2:27019"},
{_id:1,host:"shard2-1:27023"},
{_id:2,host:"shard2-2:27024"}]})'

sleep 15

docker exec mongos_router mongosh --port 27020 --quiet --eval '
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
'

docker exec shard2 mongosh --port 27019 --quiet --eval '
rs.initiate({_id: "shard2", members: [
{_id: 0, host: "shard2:27019"},
{_id: 1, host: "shard2-1:27023"},
{_id: 2, host: "shard2-2:27024"}
]})
'

sleep 20

docker exec mongos_router mongosh --port 27020 --quiet --eval '
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", {name:"hashed"});
db = db.getSiblingDB("somedb");
for (var i=0;i<1000;i++) db.helloDoc.insertOne({age:i,name:"ly"+i});
print(db.helloDoc.countDocuments());
db.getSiblingDB("somedb").helloDoc.getShardDistribution()
db.adminCommand({listShards:1}).shards.map(s => s.host)
'
