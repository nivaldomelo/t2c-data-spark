# Imagem do cluster Spark do t2c_data — Spark 3.5.1 + libs (JDBC MySQL/Postgres, hadoop-aws p/ S3).
# Master e worker usam a MESMA imagem (o comando é definido no chart). Non-root (uid 185 = spark).
FROM apache/spark:3.5.1

USER root

# Versões pinadas (Spark 3.5.1 embarca Hadoop 3.3.4).
ARG POSTGRES_JDBC=42.7.10
ARG MYSQL_JDBC=9.1.0
ARG HADOOP_AWS=3.3.4
ARG AWS_SDK_BUNDLE=1.12.262

# Libs adicionadas ao classpath do Spark (executores + driver em cluster-mode).
# HARDENING (supply-chain, recomendado pelo DevOps): fixar e verificar o SHA-256 de cada JAR
# (obtido out-of-band de fonte confiável) após o download, ex.:
#   echo "<sha256>  postgresql-${POSTGRES_JDBC}.jar" | sha256sum -c -
# Versões já estão pinadas via ARG; falta a verificação de integridade.
RUN set -eux; \
    cd /opt/spark/jars; \
    curl -fSL -o "postgresql-${POSTGRES_JDBC}.jar" \
      "https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC}/postgresql-${POSTGRES_JDBC}.jar"; \
    curl -fSL -o "mysql-connector-j-${MYSQL_JDBC}.jar" \
      "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_JDBC}/mysql-connector-j-${MYSQL_JDBC}.jar"; \
    curl -fSL -o "hadoop-aws-${HADOOP_AWS}.jar" \
      "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS}/hadoop-aws-${HADOOP_AWS}.jar"; \
    curl -fSL -o "aws-java-sdk-bundle-${AWS_SDK_BUNDLE}.jar" \
      "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_BUNDLE}/aws-java-sdk-bundle-${AWS_SDK_BUNDLE}.jar"

# Defaults do cluster (S3A, event log). Sobrescrevíveis por ConfigMap montado no chart.
COPY conf/spark-defaults.conf /opt/spark/conf/spark-defaults.conf

# Scratch local do Spark (compatível com readOnlyRootFilesystem: montar emptyDir aqui no chart).
RUN mkdir -p /tmp/spark-local /tmp/spark-events && chown -R 185:185 /tmp/spark-local /tmp/spark-events

USER 185

EXPOSE 7077 8080 8081
