#!/usr/bin/env bash

sudo docker-compose down

sudo docker build -t cluster:node .
sudo docker-compose up -d

sudo bash sbin/deploy-ssh-keys.sh
sudo bash sbin/deploy-ssh-authorized-keys.sh

sudo docker exec metastore mysql -u root -p root -e "CREATE DATABASE hive;
  CREATE DATABASE airflow;
  CREATE USER hive IDENTIFIED BY 'hive';
  CREATE USER airflow IDENTIFIED BY 'airflow';
  GRANT ALL PRIVILEGES ON hive.* TO 'hive'@'%';
  GRANT ALL PRIVILEGES ON airflow.* TO 'airflow'@'%';"

sudo docker exec slave01 service rabbitmq-server start
sudo docker exec slave01 rabbitmq-plugins enable rabbitmq_management
sudo docker exec slave01 rabbitmqctl add_user airflow airflow
sudo docker exec slave01 rabbitmqctl set_user_tags airflow administrator
sudo docker exec slave01 rabbitmqctl set_permissions -p airflow ".*" ".*" ".*"

sudo docker exec master01 airflow db init
sudo docker exec master01 airflow users create --username admin  --password admin \
  --firstname FIRST_NAME --lastname LAST_NAME --role Admin --email admin@example.org
sudo docker exec master01 airflow celery worker
sudo docker exec master02 airflow celery worker
sudo docker exec slave01 airflow celery worker
sudo docker exec slave02 airflow celery worker
sudo docker exec slave03 airflow celery worker
sudo docker exec slave01 airflow celery flower
sudo docker exec -d slave01 sh -c "airflow webserver --port 5080 > /usr/local/lib/apache-airflow-2.5.0/logs/webserver.log"

sudo bash lib/apache-zookeeper-3.7.1-bin/sbin/deploy-myid.sh
sudo docker exec master01 zkServer.sh start
sudo docker exec master02 zkServer.sh start
sudo docker exec slave01 zkServer.sh start
sudo docker exec master01 hdfs zkfc -formatZK
sudo docker exec master01 hdfs --daemon start journalnode
sudo docker exec master02 hdfs --daemon start journalnode
sudo docker exec slave01 hdfs --daemon start journalnode

sudo docker exec master01 hdfs namenode -format
sudo docker exec master01 start-dfs.sh
sudo docker exec master02 hdfs namenode -bootstrapStandby

sudo docker exec master01 start-yarn.sh
sudo docker exec master01 mapred --daemon start historyserver
sudo docker exec master02 mapred --daemon start historyserver