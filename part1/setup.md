# Setup

## Install a HA Redis Cluster

Please install a highly available Redis cluster in your namespace:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
# change the namespace to your user namespace `user-<n>`.
helm install -n user-0 cache bitnami/redis-cluster
```

## Install the Sample Application

Install the sample app using the following command:

```bash
# change the namespace to your user namespace `user-<n>`.
# this assumes you are in the directory in which this file is contained.
helm install -n user-0 sample-app ./sample-app
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
