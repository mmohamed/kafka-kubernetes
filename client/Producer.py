from kafka import KafkaProducer
from kafka.errors import KafkaError
import logging
import sys

logger = logging.getLogger('kafka')
logger.addHandler(logging.StreamHandler(sys.stdout))
logger.setLevel(logging.INFO)

print('Init producer...')
producer = KafkaProducer(bootstrap_servers=['127.0.0.1:9092'])

# Asynchronous by default
print('Send a hello message...')
future = producer.send('k8s', b'Hello, I\'m  producer :)')

# Block for 'synchronous' sends
try:
    record_metadata = future.get(timeout=10)
except KafkaError:
    logger.exception(KafkaError)
    pass

print('Sending metadata...')
print (record_metadata.topic)
print (record_metadata.partition)
print (record_metadata.offset)