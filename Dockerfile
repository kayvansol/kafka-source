FROM docker.arvancloud.ir/confluentinc/cp-kafka-connect:latest

RUN confluent-hub install confluentinc/kafka-connect-jdbc:10.7.6 --no-prompt
RUN confluent-hub install debezium/debezium-connector-sqlserver:2.4.2 --no-prompt
