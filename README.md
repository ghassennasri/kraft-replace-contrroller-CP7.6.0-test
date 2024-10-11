
# Kafka KRaft Controller Migration

The goal of this process is to decommission `controller-3` and replace it with `controller-3_migrated`, while keeping the same `nodeID=3` and the same `ClusterID="MkU3OEVBNTcwNTJENDM2Qk"`. The migration involves the following steps:

1. **Check Metadata Replication Lag**:
   - Ensure the metadata replication lag for nodes 1, 2, and the observer node 4 is zero.

2. **Stop Controller-3 Definitively**:
   - Shut down `controller-3` to prepare for the migration.

3. **Change `controller.quorum.voters` Property**:
   - Update the `controller.quorum.voters` configuration for `controller-1`, `controller-2`, and the broker from:
     `"1@controller-1:9093,2@controller-2:9093,3@controller-3:9093"` 
     to:
     `"1@controller-1:9093,2@controller-2:9093,3@controller-3_migrated:9093"`.

4. **Restart Controllers and Broker**:
   - Start `controller-1`, `controller-2`, `controller-3_migrated`, and the broker with the new configuration.

5. **Restart Control Center**:
   - Control Center needed a restart due to its embedded Kafka Streams application encountering a fatal exception.

6. **Metadata Verification**:
   - Metadata checks were performed by comparing the `HighWatermark` from the output of:
     ```
     docker exec broker kafka-metadata-quorum --bootstrap-server localhost:9092 describe --status
     ```
     both before and after the migration, ensuring that the `HighWatermark` increased.

7. **Further Verification**:
   - A Datagen connector was created to produce data into the `orders` topic before the migration. The script ensured the topic remained available after the migration, and that the connector continued running with the last offset still increasing.
     Connector endured a rebalance due to broker restart but restarted on its own and resumed producing to orders topic
   - Before the migration, A KSQL stream orders_stream and a KSQL select query was issued on it writing output to ksqlOutput.log file. KSQL stream endured a rebalance and resumed successfuly on its own after the migration

## How to run this demo
From project directory run:
```bash
./start.sh
```
## Output example
```text
Starting the Docker Compose environment...
Creating network "kraft-groupama_default" with the default driver
Creating controller-3 ... done
Creating controller-1 ... done
Creating controller-2 ... done
Creating broker       ... done
Creating schema-registry ... done
Creating connect         ... done
Creating ksqldb-server   ... done
Creating ksql-datagen    ... done
Creating control-center  ... done
Creating ksqldb-cli      ... done
Waiting for services to be ready...
Waiting for Kafka broker to be ready...
[2024-10-11 08:34:21,574] INFO AdminClientConfig values: 
        auto.include.jmx.reporter = true
        bootstrap.servers = [broker:29092]
        client.dns.lookup = use_all_dns_ips
        client.id = 
        connections.max.idle.ms = 300000
        default.api.timeout.ms = 60000
        metadata.max.age.ms = 300000
        metric.reporters = []
        metrics.num.samples = 2
        metrics.recording.level = INFO
        metrics.sample.window.ms = 30000
        receive.buffer.bytes = 65536
        reconnect.backoff.max.ms = 1000
        reconnect.backoff.ms = 50
        request.timeout.ms = 30000
        retries = 2147483647
        retry.backoff.ms = 100
        sasl.client.callback.handler.class = null
        sasl.jaas.config = null
        sasl.kerberos.kinit.cmd = /usr/bin/kinit
        sasl.kerberos.min.time.before.relogin = 60000
        sasl.kerberos.service.name = null
        sasl.kerberos.ticket.renew.jitter = 0.05
        sasl.kerberos.ticket.renew.window.factor = 0.8
        sasl.login.callback.handler.class = null
        sasl.login.class = null
        sasl.login.connect.timeout.ms = null
        sasl.login.read.timeout.ms = null
        sasl.login.refresh.buffer.seconds = 300
        sasl.login.refresh.min.period.seconds = 60
        sasl.login.refresh.window.factor = 0.8
        sasl.login.refresh.window.jitter = 0.05
        sasl.login.retry.backoff.max.ms = 10000
        sasl.login.retry.backoff.ms = 100
        sasl.mechanism = GSSAPI
        sasl.oauthbearer.clock.skew.seconds = 30
        sasl.oauthbearer.expected.audience = null
        sasl.oauthbearer.expected.issuer = null
        sasl.oauthbearer.jwks.endpoint.refresh.ms = 3600000
        sasl.oauthbearer.jwks.endpoint.retry.backoff.max.ms = 10000
        sasl.oauthbearer.jwks.endpoint.retry.backoff.ms = 100
        sasl.oauthbearer.jwks.endpoint.url = null
        sasl.oauthbearer.scope.claim.name = scope
        sasl.oauthbearer.sub.claim.name = sub
        sasl.oauthbearer.token.endpoint.url = null
        security.protocol = PLAINTEXT
        security.providers = null
        send.buffer.bytes = 131072
        socket.connection.setup.timeout.max.ms = 30000
        socket.connection.setup.timeout.ms = 10000
        ssl.cipher.suites = null
        ssl.enabled.protocols = [TLSv1.2, TLSv1.3]
        ssl.endpoint.identification.algorithm = https
        ssl.engine.factory.class = null
        ssl.key.password = null
        ssl.keymanager.algorithm = SunX509
        ssl.keystore.certificate.chain = null
        ssl.keystore.key = null
        ssl.keystore.location = null
        ssl.keystore.password = null
        ssl.keystore.type = JKS
        ssl.protocol = TLSv1.3
        ssl.provider = null
        ssl.secure.random.implementation = null
        ssl.trustmanager.algorithm = PKIX
        ssl.truststore.certificates = null
        ssl.truststore.location = null
        ssl.truststore.password = null
        ssl.truststore.type = JKS
 (org.apache.kafka.clients.admin.AdminClientConfig)
[2024-10-11 08:34:22,380] INFO Kafka version: 7.6.0-ccs (org.apache.kafka.common.utils.AppInfoParser)
[2024-10-11 08:34:22,380] INFO Kafka commitId: 1991cb733c81d679 (org.apache.kafka.common.utils.AppInfoParser)
[2024-10-11 08:34:22,380] INFO Kafka startTimeMs: 1728635662375 (org.apache.kafka.common.utils.AppInfoParser)
[2024-10-11 08:34:22,426] INFO [AdminClient clientId=adminclient-1] Node -1 disconnected. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:34:22,430] WARN [AdminClient clientId=adminclient-1] Connection to node -1 (broker/172.28.0.5:29092) could not be established. Broker may not be available. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:34:22,559] INFO [AdminClient clientId=adminclient-1] Node -1 disconnected. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:34:22,559] WARN [AdminClient clientId=adminclient-1] Connection to node -1 (broker/172.28.0.5:29092) could not be established. Broker may not be available. (org.apache.kafka.clients.NetworkClient)
Using log4j config /etc/kafka/log4j.properties
Waiting for Schema Registry to be ready...
Waiting for Connect to be ready...
Waiting for ksqlDB server to be ready...
Waiting for Control Center to be ready...
All components are up and ready.
All components are up and ready.
Creating the Datagen connector to produce messages to the 'orders' topic...
{
  "name": "datagen-orders",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "name": "datagen-orders",
    "kafka.topic": "orders",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "max.interval": "1",
    "iterations": "100000000",
    "tasks.max": "1",
    "schema.filename": "/tmp/schemas/orders.avro",
    "schema.keyfield": "orderid"
  },
  "tasks": [],
  "type": "source"
}
Creating a ksqlDB stream for the 'orders' topic...
[{"@type":"currentStatus","statementText":"CREATE STREAM ORDERS_STREAM (ORDERTIME BIGINT, ORDERID INTEGER, PRODUCTID STRING, ORDERUNITS INTEGER, ORDER_CATEGORY STRING, CUSTOMERID STRING) WITH (CLEANUP_POLICY='delete', KAFKA_TOPIC='orders', KEY_FORMAT='KAFKA', VALUE_FORMAT='JSON');","commandId":"stream/`ORDERS_STREAM`/create","commandStatus":{"status":"SUCCESS","message":"Stream created","queryId":null},"commandSequenceNumber":0,"warnings":[]}]Running a continuous query to select all records from the orders_stream...
Checking Kafka metadata quorum status and waiting for lag to be zero for nodes 1, 2, and 4...
Lag is zero for nodes 1, 2, and 4. Proceeding with the next steps.
ClusterId:              MkU3OEVBNTcwNTJENDM2Qg
LeaderId:               1
LeaderEpoch:            3
HighWatermark:          876
MaxFollowerLag:         0
MaxFollowerLagTimeMs:   0
CurrentVoters:          [1,2,3]
CurrentObservers:       [4]
NodeId  LogEndOffset    Lag     LastFetchTimestamp      LastCaughtUpTimestamp   Status  
1       880             0       1728635786095           1728635786095           Leader  
2       880             0       1728635785921           1728635785921           Follower
3       880             0       1728635785923           1728635785923           Follower
4       880             0       1728635785918           1728635785918           Observer
Stopping controller-3...
Stopping controller-3 ... done
Modifying controller.quorum.voters for controller-1...
Modifying controller.quorum.voters for controller-2...
Modifying controller.quorum.voters for broker...
Restarting controller-1...
Restarting controller-1 ... done
Restarting controller-2...
Restarting controller-2 ... done
Restarting broker...
Restarting broker ... done
Starting the Docker Compose environment with the migrate profile...
controller-1 is up-to-date
controller-2 is up-to-date
broker is up-to-date
schema-registry is up-to-date
connect is up-to-date
ksqldb-server is up-to-date
ksqldb-cli is up-to-date
ksql-datagen is up-to-date
control-center is up-to-date
Creating controller-3_migrated ... done
Restarting control-center ... done
Checking if the latest offset in the 'orders' topic is increasing...
[2024-10-11 08:37:03,287] WARN [AdminClient clientId=GetOffsetShell] Connection to node -1 (broker/172.28.0.4:29092) could not be established. Node may not be available. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:37:03,393] WARN [AdminClient clientId=GetOffsetShell] Connection to node -1 (broker/172.28.0.4:29092) could not be established. Node may not be available. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:37:03,595] WARN [AdminClient clientId=GetOffsetShell] Connection to node -1 (broker/172.28.0.4:29092) could not be established. Node may not be available. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:37:03,897] WARN [AdminClient clientId=GetOffsetShell] Connection to node -1 (broker/172.28.0.4:29092) could not be established. Node may not be available. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:37:04,299] WARN [AdminClient clientId=GetOffsetShell] Connection to node -1 (broker/172.28.0.4:29092) could not be established. Node may not be available. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:37:05,204] WARN [AdminClient clientId=GetOffsetShell] Connection to node -1 (broker/172.28.0.4:29092) could not be established. Node may not be available. (org.apache.kafka.clients.NetworkClient)
[2024-10-11 08:37:06,312] WARN [AdminClient clientId=GetOffsetShell] Connection to node -1 (broker/172.28.0.4:29092) could not be established. Node may not be available. (org.apache.kafka.clients.NetworkClient)
Initial offset: 2981042
Latest offset after waiting: 2981042
The offset is not increasing. Datagen connector may have stopped producing to the 'orders' topic.
ClusterId:              MkU3OEVBNTcwNTJENDM2Qg
LeaderId:               2
LeaderEpoch:            10
HighWatermark:          950
MaxFollowerLag:         0
MaxFollowerLagTimeMs:   413
CurrentVoters:          [1,2,3]
CurrentObservers:       [4]
NodeId  LogEndOffset    Lag     LastFetchTimestamp      LastCaughtUpTimestamp   Status  
2       954             0       1728635844290           1728635844290           Leader  
1       954             0       1728635843867           1728635843867           Follower
3       954             0       1728635843865           1728635843865           Follower
4       954             0       1728635843864           1728635843864           Observer
Checking if the latest offset in the 'orders' topic is increasing...
Initial offset: 5206672
Latest offset after waiting: 5647240
The offset is increasing. Datagen connector is still producing to the 'orders' topic.
Migration is complete
```