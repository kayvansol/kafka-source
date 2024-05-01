# Debezium source connector from SQL Server to Apache Kafka

Docker file for the connector that installing debezium-connector-sqlserver library [Dockerfile](https://github.com/kayvansol/kafka-source/blob/main/Dockerfile):
```bash
FROM docker.arvancloud.ir/confluentinc/cp-kafka-connect:latest

RUN confluent-hub install confluentinc/kafka-connect-jdbc:10.7.6 --no-prompt
RUN confluent-hub install debezium/debezium-connector-sqlserver:2.4.2 --no-prompt
```

the build command :
```bash
docker build -t docker.arvancloud.ir/confluentinc/cp-kafka-connect:latest .
```

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/kafka-connect-with_debezum.png?raw=true)

```bash
cd Kafka-source
```
Docker Compose file [docker-compose.yml](https://github.com/kayvansol/kafka-source/blob/main/docker-compose.yml) :
```yml
---
version: '3'

services:

  zookeeper2:
    image: docker.arvancloud.ir/confluentinc/cp-zookeeper:latest
    hostname: zookeeper2
    container_name: zookeeper2
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    networks:
      - kafka-network1

  kafka1:
    image: docker.arvancloud.ir/confluentinc/cp-kafka:latest
    hostname: kafka1
    container_name: kafka1
    depends_on:
      - zookeeper2
    ports:
      - "29092:29092"
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper2:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka1:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'
      CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: kafka1:29092
      CONFLUENT_METRICS_REPORTER_ZOOKEEPER_CONNECT: zookeeper2:2181
      CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS: 1
      CONFLUENT_METRICS_ENABLE: 'false'
    networks:
      - kafka-network1

  connect1:
    image: docker.arvancloud.ir/confluentinc/cp-kafka-connect:latest
    hostname: connect1
    container_name: connect1
    depends_on:
      - zookeeper2
      - kafka1
    ports:
      - '8083:8083'
    environment:
      CONNECT_BOOTSTRAP_SERVERS: 'kafka1:29092'
      CONNECT_REST_ADVERTISED_HOST_NAME: connect1
      CONNECT_REST_PORT: 8083
      CONNECT_GROUP_ID: compose-connect-group
      CONNECT_CONFIG_STORAGE_TOPIC: docker-connect-configs
      CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_OFFSET_FLUSH_INTERVAL_MS: 10000
      CONNECT_OFFSET_STORAGE_TOPIC: docker-connect-offsets
      CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_STATUS_STORAGE_TOPIC: docker-connect-status
      CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_KEY_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_VALUE_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_INTERNAL_KEY_CONVERTER: 'org.apache.kafka.connect.json.JsonConverter'
      CONNECT_INTERNAL_VALUE_CONVERTER: 'org.apache.kafka.connect.json.JsonConverter'
      CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE: 'false'
      CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE: 'false'
      CONNECT_ZOOKEEPER_CONNECT: 'zookeeper2:2181'
      # CLASSPATH required due to CC-2422
      CLASSPATH: /usr/share/java/monitoring-interceptors/monitoring-interceptors-5.4.1.jar
      CONNECT_PRODUCER_INTERCEPTOR_CLASSES: 'io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor'
      CONNECT_CONSUMER_INTERCEPTOR_CLASSES: 'io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor'
      CONNECT_PLUGIN_PATH: '/usr/share/java,/usr/share/confluent-hub-components'
      CONNECT_LOG4J_LOGGERS: org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR
    networks:
      - kafka-network1

  akhq1:
    image: tchiotludo/akhq
    hostname: web-ui1
    container_name: web-ui1
    environment:
      AKHQ_CONFIGURATION: |
        akhq:
          connections:
            docker-kafka-server:
              properties:
                bootstrap.servers: "kafka1:29092"              
              connect:
                - name: "connect"
                  url: "http://connect1:8083"

    ports:
      - 8080:8080
    links:
      - kafka1
    networks:
      - kafka-network1

networks:
  kafka-network1:
    driver: bridge
    name: kafka-network1

```
```
docker compose up
```
Docker Desktop :

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/Containers.png?raw=true)

then check all the container's logs for being healthy.

Configuring Microsoft SQL Server to Enable CDC :
```
﻿
CREATE DATABASE Test_DB;
GO
USE Test_DB;
EXEC sys.sp_cdc_enable_db;ALTER DATABASE Test_DB
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON)


CREATE TABLE prospects (
  id INTEGER IDENTITY(1001,1) NOT NULL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);

EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'prospects', @role_name = NULL, @supports_net_changes = 0;
GO

```

Restart SQL Server instance and agent 

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/enable-cdc.png?raw=true)

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/cdc-tables.png?raw=true)

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/cdc-jobs.png?raw=true)

then create a kafka connector to sql server :

```
docker exec -it connect1 bash
```

```powershell

curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors -d '{ "name": "debezium-connector", 
"config": { 
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "database.hostname": "192.168.1.4", 
    "database.port": "1433", 
    "database.user": "sa",
    "database.password": "ABCabc123456", 
    "database.dbname": "Test_DB", 
    "database.names":"Test_DB",
    "database.server.name": "192.168.1.4", 
    "table.whitelist": "dbo.prospects", 
    "topic.prefix": "fullfillment",
    "database.history.kafka.bootstrap.servers": "kafka1:29092", 
    "database.history.kafka.topic": "schema-changes-topic",
    "errors.log.enable": "true",
    "schema.history.internal.kafka.bootstrap.servers": "kafka1:29092",  
    "schema.history.internal.kafka.topic": "schema-changes.inventory",
    "database.trustServerCertificate": true  } 
}';
```
![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/connector.png?raw=true)

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/CreatedConnector.png?raw=true)

and after inserting new data to related sql server table, the connector sync kafka topic with the new data :

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/Insertnew.png?raw=true)

go to [http://localhost:8080/ui/docker-kafka-server/topic/usertopic/data?sort=Oldest&partition=All](http://localhost:8080/ui/docker-kafka-server/topic/usertopic/data?sort=Oldest&partition=All)

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/topicValues.png?raw=true)

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/topicValues2.png?raw=true)

![alt text](https://raw.githubusercontent.com/kayvansol/kafka-source/main/img/topicValues3.png?raw=true)

