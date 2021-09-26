# Setup

## Prometheus Setup

Get the kube-prometheus repository:

```bash
git clone https://github.com/prometheus-operator/kube-prometheus.git
```

Then install everything:

```bash
cd kube-prometheus
kubectl create -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl create -f manifests/
```

Now wait a little. This will start a lot of containers in the `monitoring` namespace. Note that the
`node-exporter` pods might fail. If this is the case use the following command:

```bash
kubectl -n monitoring edit ds/node-exporter
```

and remove the lines containing `mountPropagation` in the `volumeMounts` section (there should be
two lines). After this save and close the file, which should update the DaemonSet and the pods
should come up.

### Create SM

We will use a single service monitor for all Redis instances:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  annotations:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: redis-exporter
    app.kubernetes.io/part-of: kube-prometheus
    app.kubernetes.io/version: 0.19.0
  labels:
    app.kubernetes.io/instance: cache
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis-cluster
    helm.sh/chart: redis-cluster-6.3.6
  name: cache-redis-cluster
  namespace: monitoring
spec:
  endpoints:
  - interval: 10s
    port: metrics
  selector:
    matchLabels:
      app.kubernetes.io/instance: cache
      app.kubernetes.io/name: redis-cluster
```

Apply it to the cluster.


## User Setup

> This is automated for the workshop:
>
> ```bash
> bash ./bootstrap.sh [env-count]
> ```

### Install a HA Redis Cluster

Please install a highly available Redis cluster in your namespace:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
# change the namespace to your user namespace `user-<n>`.
helm install -n user-0 cache bitnami/redis-cluster \
  --set "metrics.enabled=true"
```

### Install the Sample Application

Install the sample app using the following command:

```bash
# change the namespace to your user namespace `user-<n>`.
# this assumes you are in the directory in which this file is contained.
helm install -n user-0 sample-app part1/sample-app
```

You can test that the application works by performing the following actions:

```bash
# create a port forward to the application
kubectl port-forward -n user-0 svc/sample-app 8080:80 &
# publish data to the application
curl -X PUT localhost:8080/my-key -d 'my-value'
# retrieve data from the application
curl localhost:8080/my-key
```
