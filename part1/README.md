# Exercises

* [Inspect the State of Your Cluster](#inspect-the-state-of-your-cluster)
* [Scale your Application](#scale-your-application)
* [Investigate Probes](#investigate-probes)
* [Configure Liveness Probe](#configure-liveness-probe)
* [Configure Readiness Probe](#configure-readiness-probe)

---

## Inspect the State of Your Cluster

Check how many pods run in your namespace, and how many of these are from the `sample-app`.

<details>
  <summary>Solution</summary>

Get the pods in the namespace:

```
$ kubectl -n user-0 get pods
NAME                          READY   STATUS    RESTARTS   AGE
cache-redis-cluster-0         1/1     Running   0          46m
cache-redis-cluster-1         1/1     Running   0          46m
cache-redis-cluster-2         1/1     Running   0          46m
cache-redis-cluster-3         1/1     Running   0          46m
cache-redis-cluster-4         1/1     Running   0          46m
cache-redis-cluster-5         1/1     Running   0          46m
sample-app-5795dc79d8-l56ch   1/1     Running   0          17m
```

There are 6 pods for Redis, and only one for `sample-app`.

</details>

Now check the replica count on the deployment of `sample-app`.

<details>
  <summary>Solution</summary>

We get the deployment names:

```
$ kubectl -n user-0 get deployments
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
sample-app   1/1     1            1           19m
```

Then we can describe the deployment:

```
$ kubectl -n user-0 describe deployment sample-app
Name:                   sample-app
Namespace:              user-0
CreationTimestamp:      Sun, 26 Sep 2021 13:32:56 +0200
Labels:                 app.kubernetes.io/managed-by=Helm
Annotations:            deployment.kubernetes.io/revision: 1
                        meta.helm.sh/release-name: sample-app
                        meta.helm.sh/release-namespace: user-0
Selector:               app.kubernetes.io/instance=sample-app,app.kubernetes.io/name=sample-app
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app.kubernetes.io/instance=sample-app
           app.kubernetes.io/name=sample-app
  Containers:
   sample-app:
    Image:      f4z3r/sample-app:0.1.0
    Port:       8080/TCP
    Host Port:  0/TCP
    Limits:
      cpu:     200m
      memory:  256Mi
    Requests:
      cpu:     100m
      memory:  128Mi
    Environment:
      REDIS_PW:        <set to the key 'redis-password' in secret 'cache-redis-cluster'>  Optional: false
      REDIS_BASE_URL:  cache-redis-cluster
    Mounts:            <none>
  Volumes:             <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   sample-app-5795dc79d8 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  20m   deployment-controller  Scaled up replica set sample-app-5795dc79d8 to 1
```

We can see under `replicas` that we have a single desired replica, and that one is available.

</details>

## Scale your Application

A simple replica application is not highly available. If the pod crashes, your application is down
until Kubernetes has managed to launch a new pod. Let us scale the application to 3 replicas.

<details>
  <summary>Solution</summary>

Using the `scale` command:

```
$ kubectl -n user-0 scale deployment sample-app --replicas=3
deployment.apps/sample-app scaled
```

Let us check the pods again:

```
$ kubectl -n user-0 get pods
NAME                          READY   STATUS    RESTARTS   AGE
cache-redis-cluster-0         1/1     Running   0          53m
cache-redis-cluster-1         1/1     Running   0          53m
cache-redis-cluster-2         1/1     Running   0          53m
cache-redis-cluster-3         1/1     Running   0          53m
cache-redis-cluster-4         1/1     Running   0          53m
cache-redis-cluster-5         1/1     Running   0          53m
sample-app-5795dc79d8-6wxjw   1/1     Running   0          46s
sample-app-5795dc79d8-l56ch   1/1     Running   0          24m
sample-app-5795dc79d8-s5fhq   1/1     Running   0          46s
```

We can see we now have 3 pods running.

</details>

## Investigate Probes

Currently, as soon as the container of our application is started, it is assumed to be running and
ready to serve requests. This is not the case in real life. We will configure liveness and readiness
probes. But first, figure out what could be the dependency for the readiness probe. You can inspect
the code that is running on the cluster in [`assets/main.go`][main.go].

[main.go]: assets/main.go

Further information: [Probes, official documentation][probes].

[probes]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

<details>
  <summary>Solution</summary>

The readiness probe determines when the server can accept incoming requests, and process them. In
the case of our application, we can see in the code that is uses Redis as a persistence layer. If it
cannot contact Redis, it cannot serve requests, and should therefore not be marked as `Ready`.
Specifically, we can see this in the readiness probe implementation of the application:

```go
http.HandleFunc("/readiness", func(w http.ResponseWriter, r *http.Request) {
    err := rdb.ForEachShard(ctx, func(ctx context.Context, shard *redis.Client) error {
        return shard.Ping(ctx).Err()
    })

    if err != nil {
       http.Error(w, "not ready yet!", 500) 
    } else {
        fmt.Fprint(w, "ready!\n")
    }
})
```

You can see here that if the application cannot contact each Redis shard (via a ping), it will
return an error, marking it as "not ready". This makes sense as not being able to contact a shard
implies it might not be able to serve a request.

</details>

## Configure Liveness Probe

Configure the liveness probe in the deployment. We will want to check liveness every 3 seconds, with
an initial delay of a single second. You can check in the code, the endpoint for this probe is
`/liveness` and the server runs on port `8080`.

<details>
  <summary>Solution</summary>

We will want to edit the deployment:

```bash
kubectl -n user-0 edit deployment sample-app
```

Under `spec.template.spec.containers[0]` add the following lines:

```yaml
livenessProbe:
  httpGet:
    path: /liveness
    port: 8080
  initialDelaySeconds: 1
  periodSeconds: 3
```

If you edited the deployment correctly, you should get the following output:

```
deployment.apps/sample-app edited
```

</details>

## Configure Readiness Probe

Configure the readiness probe in the deployment. We will want to check readiness every 3 seconds, with
an initial delay of 2 seconds. You can check in the code, the endpoint for this probe is
`/readiness` and the server runs on port `8080`.

<details>
  <summary>Solution</summary>

We will want to edit the deployment:

```bash
kubectl -n user-0 edit deployment sample-app
```

Under `spec.template.spec.containers[0]` add the following lines (you can add it directly under the
liveness probe):

```yaml
readinessProbe:
  httpGet:
    path: /readiness
    port: 8080
  initialDelaySeconds: 2
  periodSeconds: 3
```

If you edited the deployment correctly, you should get the following output:

```
deployment.apps/sample-app edited
```

Note that every time you perform such a change, Kubernetes will automatically perform rolling
updates of the deployment. Therefore it will not cause any downtime of your application during the
update process:

```
$ kubectl -n user-0 get pods
NAME                          READY   STATUS              RESTARTS   AGE
cache-redis-cluster-0         1/1     Running             0          74m
cache-redis-cluster-1         1/1     Running             0          74m
cache-redis-cluster-2         1/1     Running             0          74m
cache-redis-cluster-3         1/1     Running             0          74m
cache-redis-cluster-4         1/1     Running             0          74m
cache-redis-cluster-5         1/1     Running             0          74m
sample-app-5f579f7fbc-bfxmr   0/1     ContainerCreating   0          16s
sample-app-7c88697fdf-2p646   1/1     Running             0          4m31s
sample-app-7c88697fdf-56v66   1/1     Running             0          4m57s
sample-app-7c88697fdf-6tpgf   1/1     Running             0          5m22s
```

See how a fourth container is started (in `ContainerCreating` state) before any of the three running
containers are stopped. Kubernetes will start a single container with the new configuration before
it deletes an old one. Then it will start a second new one, wait for this one to be `Ready` before
killing a second old one. And so forth.

</details>

## Ensure the Pods run on different Nodes

What if all our pods run on the same node? If that node crashes, all pods will be down and will need
to be rescheduled. During this time, the application will be down! Let us configure the deployment
in such a way that all 3 pods run on different nodes.

For more information see: [Affinity and anti-affinity of the Kubernetes documentation][affinity].

[affinity]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity

<details>
  <summary>Solution</summary>

We will need to use a pod anti-affinity, to ensure no pod from our deployment is scheduled onto a
node that already contains a pod from our deployment.

See: [Inter-pod affinity and anti-affinity][pod-affinity]

[pod-affinity]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity

There are several things to consider now:

1. What kind of anti-affinity do we want? Should we consider this during scheduling only, or also
   during runtime?
2. What labels should be match on? How can our application pods be identified?
3. Based on what topology are we basing ourselves?

Regarding the first question, we need to consider what can possibly happen. Currently, we assume no
other teams deploy applications with the same label sets as we do, so checking affinities at
schedule time and runtime is equivalent. Moreover, we will chose a "preferred" mode, instead of
"required", since we would rather schedule two pods on the same node as not schedule at all.
Therefore we pick `preferredDuringSchedulingIgnoredDuringExecution`.

For the second question, we need to identify the pod labels that uniquely identify our application.
Let us get the labels for our application:

```bash
$ kubectl -n user-0 get pods --show-labels
NAME                          READY   STATUS    RESTARTS   AGE     LABELS
cache-redis-cluster-0         2/2     Running   0          7m13s   app.kubernetes.io/instance=cache,app.kubernetes.io/managed-by=Helm,app.kubernetes.io/name=redis-cluster,controller-revision-hash=cache-redis-cluster-6d8f9767f6,helm.sh/chart=redis-cluster-6.3.7,statefulset.kubernetes.io/pod-name=cache-redis-cluster-0
cache-redis-cluster-1         2/2     Running   0          7m13s   app.kubernetes.io/instance=cache,app.kubernetes.io/managed-by=Helm,app.kubernetes.io/name=redis-cluster,controller-revision-hash=cache-redis-cluster-6d8f9767f6,helm.sh/chart=redis-cluster-6.3.7,statefulset.kubernetes.io/pod-name=cache-redis-cluster-1
cache-redis-cluster-2         2/2     Running   0          7m13s   app.kubernetes.io/instance=cache,app.kubernetes.io/managed-by=Helm,app.kubernetes.io/name=redis-cluster,controller-revision-hash=cache-redis-cluster-6d8f9767f6,helm.sh/chart=redis-cluster-6.3.7,statefulset.kubernetes.io/pod-name=cache-redis-cluster-2
cache-redis-cluster-3         2/2     Running   0          7m13s   app.kubernetes.io/instance=cache,app.kubernetes.io/managed-by=Helm,app.kubernetes.io/name=redis-cluster,controller-revision-hash=cache-redis-cluster-6d8f9767f6,helm.sh/chart=redis-cluster-6.3.7,statefulset.kubernetes.io/pod-name=cache-redis-cluster-3
cache-redis-cluster-4         2/2     Running   0          7m12s   app.kubernetes.io/instance=cache,app.kubernetes.io/managed-by=Helm,app.kubernetes.io/name=redis-cluster,controller-revision-hash=cache-redis-cluster-6d8f9767f6,helm.sh/chart=redis-cluster-6.3.7,statefulset.kubernetes.io/pod-name=cache-redis-cluster-4
cache-redis-cluster-5         2/2     Running   0          7m12s   app.kubernetes.io/instance=cache,app.kubernetes.io/managed-by=Helm,app.kubernetes.io/name=redis-cluster,controller-revision-hash=cache-redis-cluster-6d8f9767f6,helm.sh/chart=redis-cluster-6.3.7,statefulset.kubernetes.io/pod-name=cache-redis-cluster-5
sample-app-5b85666758-cwrcf   1/1     Running   0          7m10s   app.kubernetes.io/instance=sample-app,app.kubernetes.io/name=sample-app,pod-template-hash=5b85666758,release/namespace=user-0
sample-app-5b85666758-g88xf   1/1     Running   0          86s     app.kubernetes.io/instance=sample-app,app.kubernetes.io/name=sample-app,pod-template-hash=5b85666758,release/namespace=user-0
sample-app-5b85666758-s2kjm   1/1     Running   0          86s     app.kubernetes.io/instance=sample-app,app.kubernetes.io/name=sample-app,pod-template-hash=5b85666758,release/namespace=user-0
```

We can see that `app.kubernetes.io/instance=sample-app` allows to identify our instance. However,
other applications with the same instance name are deployed in other namespaces (from the other
workshop participants). Therefore we will also need to use the `release/namespace=user-0` label to
make sure we identify only our instance from this namespace. These two labels should be enough to
uniquely identify all pods from out application instance.

Finally, for the last question, we need to define the topology domain. The topology key in an
affinity setting from Kubernetes determines the scope of the affinity. We want the scope of the
affinity to be a single node. In other words, we want the pods to be scheduled on any node that does
not already contain a pod from our deployment, without considering other topology domains such as
server zones, racks, host operating systems, machine families, cloud regions, or anything else.
Therefore we need to set the `topologyKey` to any node label that is unique for each node. For this
we typically use the `kubernetes.io/hostname` label, which provides the hostname of each node (which
obviously should be unique for each node).

This results in the following anti-affinity:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/instance
            operator: In
            values:
            - sample-app
          - key: release/namespace
            operator: In
            values:
            - user-0
        topologyKey: kubernetes.io/hostname
```

Note that we assigned a weight of 100 to the anti-affinity. This weight can be any value between 1
and 100. Since no other affinities are defined in the cluster, the value is not really relevant, but
making 100 makes it very high priority. We can now add this to the pod template in our deployment
under `spec.template.spec`.

Once this is done, there will be rolling deployment to update our instances. When the rolling
deployment is completed, we can check that all pods are running on different nodes:

```bash
$ kubectl -n user-0 get pods -l "app.kubernetes.io/instance=sample-app,release/namespace=user-0" -o wide
NAME                          READY   STATUS    RESTARTS   AGE    IP           NODE                                            NOMINATED NODE   READINESS GATES
sample-app-59b455f75d-4fwx2   1/1     Running   0          47s    10.84.0.59   gke-viscon-cluster-default-pool-ae1e0eb6-p70v   <none>           <none>
sample-app-59b455f75d-ft6lh   1/1     Running   0          75s    10.84.2.62   gke-viscon-cluster-default-pool-ae1e0eb6-vk5g   <none>           <none>
sample-app-59b455f75d-z6qhj   1/1     Running   0          103s   10.84.1.76   gke-viscon-cluster-default-pool-ae1e0eb6-58r4   <none>           <none>
```

As you can see, all pods run on a differnt node.

</details>
