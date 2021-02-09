from kafka import KafkaConsumer
import logging
import sys

logger = logging.getLogger('kafka')
logger.addHandler(logging.StreamHandler(sys.stdout))
logger.setLevel(logging.INFO)

print('Init consumer...')
consumer = KafkaConsumer(
   'k8s',
    auto_offset_reset='earliest',
    enable_auto_commit=True,
    bootstrap_servers=['127.0.0.1:9092'])
    
print('Waiting for message')
for message in consumer:
    print ("%s:%d:%d: key=%s value=%s" % (message.topic, message.partition,
                                          message.offset, message.key,
                                          message.value))

