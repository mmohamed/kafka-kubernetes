# Kafka & Zookeeper Kubernetes Deployment
Following this project, you will be able to deploy, configure and use an [Apache Kafka](https://kafka.apache.org/) event streaming platform with [Apache Zookeeper](https://zookeeper.apache.org/) , for your integration and development environment easily.

<img src="Apache-kafka.png" width="99%">

> Apache Kafka is an open-source distributed event streaming platform used by thousands of companies for high-performance data pipelines, streaming analytics, data integration, and mission-critical applications

<img src="Apache-ZooKeeper.png" width="99%">

> ZooKeeper is a centralized service for maintaining configuration information, naming, providing distributed synchronization, and providing group services

## 1- Stack :
* Kubelet : **v1.17.2 / v1.18.5**
* Kubectl : **v1.17.1**
* Docker : **19.03.5 / 19.03.8**
* Zookeeper : **3.4.10**
* Kafka : **2.7.0 (Scala 2.13 / Glib 2.31-r0)**
* Kube namespace : **kafka**
* Architecture : **AMD64 / ARM64**
* Python (optional, for client testing) : **3.8**

## 2- Zookeeper deployment :
First, deploy a small Zookeeper cluster (2 pods) using a [StatefulSet](zookeeper/statefulset.yaml) and exposing it with 2 [Services](zookeeper/service.yaml), one for client communication and another for Zookeeper cluster communication (leader election).
```bash
kubectl apply -f zookeeper/statefulset.yaml
kubectl apply -f zookeeper/service.yaml
```
Next, you can test your deployment :
```bash
kubectl exec zk-0 zkCli.sh create /hello world
kubectl exec zk-1 zkCli.sh get /hello
```
For more information, take a tour in the [kubernetes blog](https://kubernetes.io/docs/tutorials/stateful-application/zookeeper/) .

## 3- Consumer/Producer application case :
You need to deploy a Kafka broker with ZooKeeper as synchronized services :
1. Create 2 Kafka broker with [StatefulSet](kafka/statefulset.yaml)
2. Create first topic (k8s for example), you can use one of available broker hostname or the broker service hostname : 
    - kafka-0.kafka-broker.kafka.svc.cluster.local
    - kafka-1.kafka-broker.kafka.svc.cluster.local
    - kafka-broker.kafka.svc.cluster.local

Next, create the first topic and run the first consumer client to check configuration.
```bash
kubectl apply -f service.yaml
kubectl apply -f statefulset.yaml
kubectl exec -ti kafka-0 -- kafka-topics.sh --create --topic=k8s --bootstrap-server kafka-0.kafka-broker.kafka.svc.cluster.local:9092
kubectl apply -f consumer.yaml
kubectl logs consumer
```

## 4- Development case (from Workstation with kubectl):
* You need to create a custom broker (for host binding) and activate a port forwarding to your workstation, and finally create a development topic : 
```bash
kubectl apply -f dev-brocker.yaml
kubectl port-forward pod/dev-brocker 9092:9092
kubectl exec -ti dev-brocker -- kafka-topics.sh --create --topic dev-k8s --bootstrap-server 127.0.0.1:9092
```
1. Running python consumer and producer :
```bash
pip install kafka-python
python ../client/Consumer.py
python ../client/Producer.py
```
2. Using Kafka help script client
```bash
kubectl exec -ti dev-brocker -- kafka-console-producer.sh --topic=dev-k8s --bootstrap-server 127.0.0.1:9092
>> Hello World!
>> I'm a Producer
> kubectl exec -ti dev-brocker -- kafka-console-consumer.sh --topic=k8s --from-beginning --bootstrap-server 127.0.0.1:9092
<< Hello World!
<< I'm a Producer
```

## 5- Sourcing
* Zookeeper Docker image : we use the [kubernetes-zookeeper @kow3ns](https://github.com/kow3ns/kubernetes-zookeeper) as base image.
* Kafka Docker image : we use the [kafka-docker @wurstmeister](https://github.com/wurstmeister/kafka-docker) as base with little modifications :
    * For ARM64 arch, switching base image from 'openjdk:8u212-jre-alpine' to 'openjdk:8u201-jre-alpine' to prevent container core dump [@see issue](https://github.com/openhab/openhab-docker/issues/233).
    * For K8S deployment, add a 'KAFKA_LISTENERS_COMMAND' environment parameter to build 'KAFKA_LISTENERS' on fly (to use pod hostname when container started) [@see start_kafka.sh](kafka/docker/start_kafka.sh)
    ```docker
    if [[ -n "$KAFKA_LISTENERS_COMMAND" ]]; then
        KAFKA_LISTENERS=$(eval "$KAFKA_LISTENERS_COMMAND")
        export KAFKA_LISTENERS
        unset KAFKA_LISTENERS_COMMAND
    fi
    ```

## 6- Tips
* For debugging, you can bypass the Kafka broker for topics management (kafka and ZooKeeper helpers script) :
```bash
kubectl exec -ti kafka-0 -- kafka-topics.sh --create --topic k8s --zookeeper zk-cs.kafka.svc.cluster.local:2181
kubectl exec -ti kafka-0 -- kafka-topics.sh --describe --topic k8s --zookeeper zk-cs.kafka.svc.cluster.local:2181
kubectl exec zk-1 zkCli.sh ls /brokers/topics
```
* Building multi-architecture docker image :
```bash
docker buildx build --push --platform linux/arm64/v8,linux/amd64 --tag [medinvention]/kubernetes-zookeeper:latest .
docker buildx build --push --platform linux/arm64/v8,linux/amd64 --tag [medinvention]/kafka:latest .
```

---- 

[*More information*](https://blog.medinvention.dev)

