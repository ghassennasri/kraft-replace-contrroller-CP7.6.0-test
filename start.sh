#!/bin/bash
# Function to wait for components to be ready using cub
wait_for_components() {
    echo "Waiting for Kafka broker to be ready..."
    docker exec broker cub kafka-ready -b broker:29092 1 60 || { echo "Kafka broker is not ready. Exiting."; exit 1; }

    echo "Waiting for Schema Registry to be ready..."
    docker exec schema-registry cub sr-ready schema-registry 8081 60 || { echo "Schema Registry is not ready. Exiting."; exit 1; }

    echo "Waiting for Connect to be ready..."
   #not working properly wait indefinitely?

   # docker exec connect cub connect-ready connect 8083 360 || { echo "Connect is not ready. Exiting."  }

    echo "Waiting for ksqlDB server to be ready..."
    docker exec ksqldb-server cub ksql-server-ready ksqldb-server 8088 120 || { echo "ksqlDB server is not ready. Exiting."; exit 1; }

    echo "Waiting for Control Center to be ready..."
    docker exec control-center cub control-center-ready control-center 9021 120 || { echo "Control Center is not ready. Exiting."; exit 1; }

    echo "All components are up and ready."
}
# Function to create the Datagen connector
create_datagen_connector() {
    echo "Creating the Datagen connector to produce messages to the 'orders' topic..."
    curl -s -X PUT \
        -H "Content-Type: application/json" \
        --data '{
                    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
                    "name": "datagen-orders",
                    "kafka.topic": "orders",
                    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
                    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
                    "value.converter.schemas.enable": "false",
                    "max.interval": 1,
                    "iterations": "100000000",
                    "tasks.max": "1",
                    "schema.filename" : "/tmp/schemas/orders.avro",
                    "schema.keyfield" : "orderid"
                }' \
        http://localhost:8083/connectors/datagen-orders/config | jq
}

# Function to create ksqlDB stream and run the query
create_ksql_stream_and_query() {
    echo "Creating a ksqlDB stream for the 'orders' topic..."
    curl -s -X POST http://localhost:8088/ksql \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        --data '{
                    "ksql": "CREATE STREAM orders_stream (ordertime BIGINT, orderid INTEGER, productid VARCHAR, orderunits INTEGER, order_category VARCHAR, customerid VARCHAR) WITH (KAFKA_TOPIC='\''orders'\'', VALUE_FORMAT='\''JSON'\'');",
                    "streamsProperties": {}
                }'

    echo "Running a continuous query to select all records from the orders_stream..."
    curl -s -X POST http://localhost:8088/query-stream \
        -H "Content-Type: application/vnd.ksql.v1+json" \
        --data '{
                    "sql": "SELECT * FROM orders_stream EMIT CHANGES;",
                    "streamsProperties": {"ksql.streams.auto.offset.reset": "earliest"}
                }' > ksqlOutput.log 2>&1 &
}

# Function to check if the latest offset in the topic is increasing
check_offset_increase() {
    echo "Checking if the latest offset in the 'orders' topic is increasing..."
    PREVIOUS_OFFSET=$(docker exec broker kafka-get-offsets --bootstrap-server broker:29092 --topic orders --time -1 | awk -F ':' '{sum += $3} END {print sum}')
    echo "Initial offset: $PREVIOUS_OFFSET"
    sleep 10  # Wait for a bit to see if new messages are produced

    LATEST_OFFSET=$(docker exec broker kafka-get-offsets --bootstrap-server broker:29092 --topic orders --time -1 | awk -F ':' '{sum += $3} END {print sum}')
    echo "Latest offset after waiting: $LATEST_OFFSET"

    if [ "$LATEST_OFFSET" -gt "$PREVIOUS_OFFSET" ]; then
        echo "The offset is increasing. Datagen connector is still producing to the 'orders' topic."
    else
        echo "The offset is not increasing. Datagen connector may have stopped producing to the 'orders' topic."
    fi
}

# Function to check if the consumer lag is decreasing
check_lag_decrease() {
    echo "Finding the consumer group associated with the 'orders' topic..."
    CONSUMER_GROUP=$(docker exec broker kafka-consumer-groups --bootstrap-server broker:29092 --describe --all-groups | grep "ORDERS" | grep "orders" | awk '{print $1}' | head -n 1)

    if [ -z "$CONSUMER_GROUP" ]; then
        echo "No consumer group found for the 'orders' topic that matches the criteria."
        return 1
    fi

    echo "Found consumer group: $CONSUMER_GROUP"
    echo "Monitoring the consumer lag for the consumer group: $CONSUMER_GROUP on topic: 'orders'..."
    PREVIOUS_LAG=$(docker exec broker kafka-consumer-groups --bootstrap-server broker:29092 --group "$CONSUMER_GROUP" --describe | grep "orders" | awk '{sum += $6} END {print sum}')

    if [ -z "$PREVIOUS_LAG" ]; then
        echo "Unable to retrieve the initial lag. The consumer group or topic may not be active."
        return 1
    fi

    echo "Initial lag: $PREVIOUS_LAG"

    # Monitor lag to check if it is decreasing
    TRIES=5
    INTERVAL=10  # seconds

    for ((i=1; i<=TRIES; i++)); do
        sleep $INTERVAL
        CURRENT_LAG=$(docker exec broker kafka-consumer-groups --bootstrap-server broker:29092 --group "$CONSUMER_GROUP" --describe | grep "orders" | awk '{sum += $6} END {print sum}')
        
        if [ -z "$CURRENT_LAG" ]; then
            echo "Failed to retrieve the current lag. The consumer group or topic may not be active."
            return 1
        fi

        echo "Current lag after $((i * INTERVAL)) seconds: $CURRENT_LAG"

        if [ "$CURRENT_LAG" -lt "$PREVIOUS_LAG" ]; then
            echo "The lag is decreasing."
            PREVIOUS_LAG=$CURRENT_LAG
        else
            echo "The lag is not decreasing. The consumer may not be consuming as expected."
            return 1
        fi
    done

    echo "The lag has been consistently decreasing over the monitoring period."
    return 0
}
# Function to check Kafka metadata quorum and lag for nodes 1, 2, and 4
check_quorum_and_lag() {
    echo "Checking Kafka metadata quorum status and waiting for lag to be zero for nodes 1, 2, and 4..."
    while true; do
        # Get the quorum status and filter only for nodes 1, 2, and 4
        LAGS=$(docker exec broker kafka-metadata-quorum --bootstrap-server localhost:9092 describe --replication | awk '$1 ~ /^[124]$/ {print $3}')
        
        # Check if all filtered nodes have zero lag
        ALL_ZERO=true
        for LAG in $LAGS; do
            if [ "$LAG" -ne 0 ]; then
                ALL_ZERO=false
                break
            fi
        done

        if [ "$ALL_ZERO" = true ]; then
            echo "Lag is zero for nodes 1, 2, and 4. Proceeding with the next steps."
            break
        else
            echo "Lag is not zero for all nodes 1, 2, and 4. Waiting for 5 seconds before checking again..."
            sleep 5
        fi
    done
}
# Function to start Docker Compose with the migrate profile
start_migration_profile() {
    echo "Starting the Docker Compose environment with the migrate profile..."
    KAFKA_CONTROLLER_QUORUM_VOTERS="1@controller-1:9093,2@controller-2:9093,3@controller-3_migrated:9093" \
    docker-compose --profile migrate up -d
}
# Function to modify controller.quorum.voters in the server.properties file inside the container
modify_quorum_voters() {
    local controller_name=$1
    local new_quorum_voters=$2

    echo "Modifying controller.quorum.voters for ${controller_name}..."
    docker exec ${controller_name} bash -c "sed -i 's/^controller.quorum.voters=.*/controller.quorum.voters=${new_quorum_voters}/' /etc/kafka/kafka.properties"
    
    # Verify the change
    docker exec ${controller_name} bash -c "grep '^controller.quorum.voters=' /etc/kafka/server.properties"
}

# Function to restart a controller
restart_controller() {
    local controller_name=$1
    echo "Restarting ${controller_name}..."
    docker-compose restart ${controller_name}
}

# Function to stop controller-3
stop_controller3() {
    echo "Stopping controller-3..."
    docker-compose stop controller-3
}

# Main script execution
echo "Starting the Docker Compose environment..."
KAFKA_CONTROLLER_QUORUM_VOTERS="1@controller-1:9093,2@controller-2:9093,3@controller-3:9093" \
docker-compose --profile normal up -d 

# Wait for services to be ready
echo "Waiting for services to be ready..."
wait_for_components
# [Place the waiting loop here for different services as before]

echo "All components are up and ready."

# Execute each function in sequence
create_datagen_connector
sleep 60  # Give time for the Datagen connector to start producing

create_ksql_stream_and_query

check_quorum_and_lag
#print the current controller quorum voters and replication status
docker exec broker kafka-metadata-quorum --bootstrap-server localhost:9092 describe --status
docker exec broker kafka-metadata-quorum --bootstrap-server localhost:9092 describe --replication
echo "Now starting the migration process..."
stop_controller3
KAFKA_CONTROLLER_QUORUM_VOTERS="1@controller-1:9093,2@controller-2:9093,3@controller-3_migrated:9093" 
modify_quorum_voters "controller-1" "${KAFKA_CONTROLLER_QUORUM_VOTERS}"
modify_quorum_voters "controller-2" "${KAFKA_CONTROLLER_QUORUM_VOTERS}"
modify_quorum_voters "broker" "${KAFKA_CONTROLLER_QUORUM_VOTERS}"
# Restart controller-1 and controller-2 to apply the changes
restart_controller "controller-1"
restart_controller "controller-2"
# Restart the broker to apply the changes
restart_controller "broker"
start_migration_profile
#restart control center
docker-compose restart control-center
#check_lag_decrease

# Additional steps can be added as needed
docker exec broker kafka-metadata-quorum --bootstrap-server localhost:9092 describe --status
docker exec broker kafka-metadata-quorum --bootstrap-server localhost:9092 describe --replication
echo "Migration is complete. Waiting 360s for the connect, KSQL producers to retry/consumers to rebalance and resume..."
sleep 360
check_offset_increase
check_lag_decrease
echo "Migration is complete"
