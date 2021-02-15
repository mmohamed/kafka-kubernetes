# How simply secure Kafka cluster with Kubernetes

## ZooKeeper DIGEST authentication
1. Edit account configuration (one for Zookeeper nodes, another for Kafka broker) in [config.secured.yaml](zookeeper/config.secured.yaml) file.

> Client section will be used by zkCli.sh helper srcipt to test configuration. In integration environement, Client section must be removed.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: zookeeper-jaas
type: Opaque
stringData:
  zookeeper-jaas.conf: |-
    QuorumServer {
          org.apache.zookeeper.server.auth.DigestLoginModule required
          user_zk="passcode";
    };
    QuorumLearner {
          org.apache.zookeeper.server.auth.DigestLoginModule required
          username="zk"
          password="passcode";
    }; 
    Server {
          org.apache.zookeeper.server.auth.DigestLoginModule required
          user_kafka="passcode"
          user_client="passcode";
    };
    Client {
          org.apache.zookeeper.server.auth.DigestLoginModule required
          username="client"
          password="passcode";
    };
```

2. Create Secret / ConfigMap and deploy StatefuSet:
```bash
kubectl apply -f zookeeper/config.secured.yaml
kubectl apply -f zookeeper/statefulset.secured.yaml
# Secret for kafka
kubectl apply -f kafka/config.secured.yaml
```

## Kafka SSL encryption

> If your want to disable the Host Name verification for some raison, you need to omit the extension parameter -ext and add empty environment variable to Kafka broker ```KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM=""``` or use Kafka helper script ```kafka-configs.sh --bootstrap-server [kafka-0].kafka-broker.kafka.svc.cluster.local:9092 --entity-type brokers --entity-name 0 --alter --add-config "listener.name.internal.ssl.endpoint.identification.algorithm="``` for every broker.

1. Create CA (certificate authority)
```bash
openssl req -new -x509 -keyout ca-key -out ca-cert -days 365
```

2. Generate server keystore and client keystore
```bash
keytool -keystore kafka.server.keystore.jks -alias localhost -validity 365 -genkey -keyalg RSA
keytool -keystore kafka.client.keystore.jks -alias localhost -validity 365 -genkey -keyalg RSA
```

3. Add generated CA to the trust store
```bash
keytool -keystore kafka.server.truststore.jks -alias CARoot -import -file ca-cert
keytool -keystore kafka.client.truststore.jks -alias CARoot -import -file ca-cert
```

4. Sign the key store (with passcode and ssl.cnf configuration file)
> You need to update alt_names section of ssl.cnf with list of your brokers hostname.
```bash
keytool -keystore kafka.server.keystore.jks -alias localhost -certreq -file cert-file
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 365 -CAcreateserial -passin pass:passcode -extfile ssl.cnf -extensions req_ext
keytool -keystore kafka.server.keystore.jks -alias CARoot -import -file ca-cert
keytool -keystore kafka.server.keystore.jks -alias localhost -import -file cert-signed
```

5. Sign the client keystore
```bash
keytool -keystore kafka.client.keystore.jks -alias localhost -certreq -file cert-file-client
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file-client -out cert-signed-client -days 365 -CAcreateserial -passin pass:passcode -extfile ssl.cnf -extensions req_ext
keytool -keystore kafka.client.keystore.jks -alias CARoot -import -file ca-cert
keytool -keystore kafka.client.keystore.jks -alias localhost -import -file cert-signed-client
```

6. Kafka SSL Kubernetes
Create kubernetes secret from kafka.keystore.jks and kafka.truststore.jks :
```bash
kubectl create secret generic ssl --from-literal=keystore_password=passcode --from-file=kafka.keystore.jks=ssl/kafka.server.keystore.jks --from-literal=truststore_password=passcode --from-file=kafka.truststore.jks=ssl/kafka.server.truststore.jks
```

Update Kafka StatefulSet to mount ssl secret and broker, service configuration:
```bash
kubectl apply -f kafka/statefulset.ssl.yaml
kubectl apply -f kafka/service.ssl.yaml
```

7. Testing

Use openssl to debug connectionto valid certificate data:
```bash
kubectl exec -ti zk-0 -- openssl s_client -debug -connect kafka-0.kafka-broker.kafka.svc.cluster.local:9093 -tls1
```

Create client configuration file (client.properties):
```ini
security.protocol=SSL
ssl.truststore.location=/opt/kafka/config/kafka.truststore.jks
ssl.truststore.password=passcode
ssl.keystore.location=/opt/kafka/config/client.keystore.jks
ssl.keystore.password=passcode
ssl.key.password=passcode
ssl.enabled.protocols=TLSv1.2,TLSv1.1,TLSv1
```

Send to test pod:
```bash
mkdir -p config
cp client.properties config/client.properties
cp ssl/kafka.client.keystore.jks config/client.keystore.jks
cp ssl/kafka.client.truststore.jks config/kafka.truststore.jks
kubectl cp config kafka-1:/opt/kafka
```

Run test:
```bash
kubectl exec -ti kafka-1 -- kafka-console-producer.sh --bootstrap-server kafka-0.kafka-broker.kafka.svc.cluster.local:9093 --topic k8s --producer.config /opt/kafka/config/client.properties
>> Hello with secured connection
```
```bash
kubectl exec -ti kafka-1 -- kafka-console-consumer.sh --bootstrap-server kafka-0.kafka-broker.kafka.svc.cluster.local:9093 --topic k8s -consumer.config /opt/kafka/config/client.properties --from-beginning
<< Hello with secured connection
```

Prepare Secret for client:
```bash
kubectl create secret generic client-ssl --from-file=ca-certs.pem=ssl/ca-cert --from-file=cert.pem=ssl/cert-signed-client
kubectl apply -f consumer.secured.yaml
kubectl logs consumer-secured
```


8. Sources & Links:
- [Redhat-Kafka](https://access.redhat.com/documentation/en-us/red_hat_amq/7.2/html/using_amq_streams_on_red_hat_enterprise_linux_rhel/configuring_kafka)
- [Confluence-Zookeeper](https://cwiki.apache.org/confluence/display/ZOOKEEPER/Server-Server+mutual+authentication)
- [Apache-Kafka](https://kafka.apache.org/documentation/#security_overview)
- [Bitnami-Kafka](https://github.com/bitnami/charts/issues/1279)
- [Kafka-SSL](https://stackoverflow.com/questions/54903381/kafka-failed-authentication-due-to-ssl-handshake-failed)
- [Vertica-Kafka-SSL](https://www.vertica.com/docs/9.2.x/HTML/Content/Authoring/KafkaIntegrationGuide/TLS-SSL/KafkaTLS-SSLExamplePart3ConfigureKafka.htm?tocpath=Integrating%20with%20Apache%20Kafka%7CUsing%20TLS%2FSSL%20Encryption%20with%20Kafka%7C_____7)
- [Kafka-SSL](https://gist.github.com/anoopl/85d869f7a85a70c6c60542922fc314a8)