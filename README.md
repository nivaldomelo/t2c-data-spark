# t2c-data-spark

Cluster **Apache Spark 3.5.1** (standalone: master + workers) da plataforma t2c_data, empacotado no padrão
Turn2C (imagem em ECR, Helm in-tree, deploy no EKS). É **infra de plataforma compartilhada** — o
`t2c-data-backend` o consome via `SPARK_MASTER_URL`, submetendo jobs de DQ/profiling/scan com `spark-submit`.

> Provisionado pela squad de DevOps/SRE junto com backend e frontend.

---

## 🚀 Deploy (DevOps) — variáveis de ambiente

> **Leitura obrigatória antes do primeiro deploy.** Ambientes: **`develop` → dev**, **`main` → prd**
> (não há `apc` neste projeto). O cluster Spark **não tem banco de dados nem migrações** — é runtime + libs.
> Os **jobs e o código** viajam com o `t2c-data-backend` via `spark-submit` (`--py-files`).

### No cluster (ConfigMap/Secret via Helm)
| Var | Local | Nota |
|---|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Secret | Acesso S3 (S3A: results/event logs em `s3a://…`). IRSA é direção futura. |
| `AWS_REGION` | Config | ex.: `us-east-1`. |
| `SPARK_NO_DAEMONIZE=true` | Config | mantém master/worker em foreground (probes/logs). |

Ajustes de recursos por `values` (`worker.replicas/cores/memory`, `master/worker.resources`, `scratch.sizeLimit`).
`conf/spark-defaults.conf` já configura o S3A a partir das credenciais de ambiente.

### Como o `t2c-data-backend` se conecta (definido no repo do backend, não aqui)
```
SPARK_MASTER_URL=spark://t2c-data-spark-master.<namespace>.svc.cluster.local:7077
SPARK_DRIVER_HOST=<host do driver alcançável pelos executores>
SPARK_DRIVER_BIND_ADDRESS=0.0.0.0
SPARK_RESULTS_DIR=s3a://<bucket>/<prefixo>   # em prd (pods diferentes não compartilham disco local)
```
Namespace padrão: `{env}-app` (ex.: `dev-app`, `prd-app`). Endpoint/UI **não** devem ser expostos publicamente.

---

## O que a imagem inclui
- Spark 3.5.1 (base `apache/spark:3.5.1`, non-root uid 185).
- **Libs (JDBC + S3)** no classpath: `postgresql`, `mysql-connector-j`, `hadoop-aws`, `aws-java-sdk-bundle`.
- `conf/spark-defaults.conf` (S3A via credenciais de ambiente, scratch em `/tmp/spark-local`).

## Componentes (Helm `.helm/`)
- **master** — Deployment (1 réplica), Service `t2c-data-spark-master` expondo `7077` (submit) e `8080` (UI).
- **worker** — Deployment (N réplicas, HPA opcional), registra no master; cores/memória configuráveis.
- ConfigMap (spark-defaults/envs), Secret (credenciais AWS via `secret-values.yaml` em runtime), SA, PDB.
- Storage: **emptyDir** por pod (`/tmp` → scratch/work/logs; `spark.local.dir`), `sizeLimit` configurável.
  Event logs podem ir para **S3** (`spark.eventLog.dir=s3a://...`).

## Como o t2c_data se conecta
No `t2c-data-backend`, definir:
```
SPARK_MASTER_URL=spark://t2c-data-spark-master.<namespace>.svc.cluster.local:7077
SPARK_DRIVER_HOST=<ip/host do driver alcançável pelos executores>
SPARK_DRIVER_BIND_ADDRESS=0.0.0.0
```
Namespace padrão: `{env}-app` (ex.: `dev-app`). Os jobs (`spark-jobs/`) e os drivers viajam com o backend
via `spark-submit`; o cluster fornece runtime + libs.

## Build & deploy
```bash
docker build -t t2c-data-spark:local .          # baixa as libs para /opt/spark/jars
```
Pipeline (`.github/workflows/cicd.yaml`): `init → docker (ECR {env}-{sha}) → helm upgrade -i -n {env}-app`.
Credenciais AWS via Secret (IRSA é direção futura). Envs: `dev`/`prd`/`apc` (main/develop/apice).

## Configuração (values)
`worker.replicas`, `worker.cores`, `worker.memory`, `master/worker.resources`, `scratch.sizeLimit`,
`worker.hpa.*`. Overrides por env via `--set` no deploy.

## ⚠️ Notas de plataforma (validar com DevOps)
- Spark **não** faz parte das skills Turn2C (lista oficial: EKS/RDS/SQS/SES/EC2/S3). Este repo segue os
  padrões gerais (Helm in-tree, ECR, ladder cicd, non-root, probes, HPA/PDB) — **validar `helm lint`/`helm template`**.
- **Modo de submissão:** standalone (`spark://master:7077`). Para `spark-submit` em client-mode a partir do
  pod do backend, os executores precisam alcançar o driver (`SPARK_DRIVER_HOST`) — avaliar cluster-mode ou
  Spark-on-K8s conforme a rede. Alternativa gerenciada: EMR/EMR-on-EKS.
- **Probes:** Spark não expõe endpoint de health HTTP dedicado → liveness/startup via `tcpSocket` (RPC/UI) e
  readiness via `GET /` da UI (desvio justificado do trio httpGet padrão).
- **Segurança:** endpoint/UI não devem ser expostos publicamente; sem Ingress por padrão (acesso interno ao cluster).
