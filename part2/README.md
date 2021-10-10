# Monitoring and Cluster Observability

There is already a full monitoring stack installed in the cluster. While technically GKE (our
cluster runs on Google Cloud) offer their own monitoring stack, we use the
Prometheus/Alertmanager/Grafana stack.

First we will be simply explore the amazing observability that Kubernetes offers in terms of
monitoring, nearly out of the box. Then we will go on to explore what can be achieved with such
observability for practical use cases.

> Note you will be admin on Grafana, please do not modify anything on there, simply use it in
> explorative fashion.

## Exploring Detailed Cluster State

Access Grafana with the following URL: [`http://34.98.65.73/login`][grafana]

[grafana]: http://34.98.65.73/login

> The password to log-in will be communicated to you during the workshop.

Once on Grafana, on the left sidebar hover over "Dashboards" and click on "Manage". You should get a
list of available dashboards prepared for you. Choose the `Kubernetes / Kubelet` dashboard.

You are now in a typical Grafana dashboard. Such a dashboard pulls data provided directly from
Prometheus to provide visually insightful information. Such dashboards can be very easily built to
illustrate whatever is desired, as long as the required metrics are scraped by Prometheus.

Explore the dashboard a little. For instance, note that you can find the following information on
the dashboard:

- The number of `kubelet` software components running in the cluster (the software that controls the
  container runtimes on worker nodes).
- The total number of pods managed by the cluster.
- The total number of containers managed by the cluster.
- Average operation rates (general/errors/storage/cgroup/...).
- Instance CPU usage.
- And much more.

> Note this is only a single dashboard. We provide 25 such dashboards, which only observe the
> general cluster state. None of these dashboards are application specific, to provide tailored
> insights about how specific applications are running.


## Use Dashboards to Find Information

1. What namespace is using the most CPU resources? (Use the `Kubernetes / Compute Resources /
   Cluster` dashboard)
2. What is the CPU/Memory request and actual usage of `cache-redis-cluster-0` in your namespace?
   (Use the `Kubernetes / Compute Resources / Pod` dashboard, and use the filters at the top of the
   dashboard).
3. What uses more memory in the `cache-redis-cluster-0` pod, the actual Redis software or the
   metrics exporter? (Use the `Kubernetes / Compute Resources / Pod` dashboard, and use the filters
   at the top of the dashboard).
4. How much network bandwidth does your `cache-redis-cluster-0` use (both received and transmitted)?
   (Use the `Kubernetes / Networking / Pod` dashboard, and use the filters at the top of the
   dashboard).
5. What is the availability level of our Kubernetes API server over the last 30 days? (Use the
   `Kubernetes / API server` dashboard)


## Verify the Exact Uptime of Your Redis Cluster

Use the "Explore" tab on the left side pane to get access to all metrics in Prometheus. Find the
exact uptime of the Redis instance running in your `cache-redis-cluster-0` pod.

<details>
  <summary>Solution</summary>

Use the following PromQL query (adapted to your namespace):

```
redis_uptime_in_seconds{namespace="user-0", pod="cache-redis-cluster-0"}
```

</details>

## Explore Alertmanager

Access Alertmanager with the following URL: [`http://34.149.93.166/#/alerts`][alertmanager]

[alertmanager]: http://34.149.93.166/#/alerts

See how some alerts are triggered. These alerts are defined directly via the Kubernetes API, via API
extensions called Custom Resource Definitions (CRDs). We have a very long list of alerts defined for
the cluster. However, we also defined one for Redis itself:

```
$ kubectl -n monitoring get prometheusrule redis-rules -o yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  creationTimestamp: "2021-10-09T13:04:50Z"
  generation: 1
  labels:
    app: kube-prometheus-stack
    release: prom-stack
  name: redis-rules
  namespace: monitoring
  resourceVersion: "9676641"
  uid: 8b4a88e6-47a9-4161-ba94-345c5bb884f8
spec:
  groups:
  - name: redis
    rules:
    - alert: RedisDown
      annotations:
        description: Redis down ({{ $labels.instance }}).
        summary: The Redis instance {{ $labels.instance }} is down.
      expr: redis_up == 0
      for: 1m
      labels:
        severity: critical
```

This alert defines that if `redis_up` is `0` for any such metric for over one minute, it should
trigger. Note that in this setup, triggering an alert simply means it will show up in the
Alertmanager UI, but typically this would also trigger Alertmanager receivers such as:

- sending an email to some team mailbox,
- forwarding the alert to OpsGenie for broader reach (if the alert is critical),
- automatically open an issue in some issue-tracking system (such as Jira),
- ...

Let us see if you can trigger the alert for the `cache-redis-cluster-5` pod in your namespace.

<details>
  <summary>Tip</summary>

Create a loop that kills PID 1 in the `cache-redis-cluster` container of the `cache-redis-cluster-5`
pod.

</details>

<details>
  <summary>Solution</summary>

You can figure out that you need to kill PID 1 in the Redis container by checking what is running
inside it:

```
$ kubectl -n user-0 exec -it cache-redis-cluster-5 -- sh
Defaulted container "cache-redis-cluster" out of: cache-redis-cluster, metrics
# ps aux ww
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
1001           1  0.2  0.2 136432  8432 ?        Ssl  13:27   0:01 redis-server 0.0.0.0:6379 [cluster]
1001        1676  0.0  0.0   2384   700 pts/0    Ss   13:34   0:00 sh
1001        1713  0.0  0.0   7636  2728 pts/0    R+   13:34   0:00 ps aux ww
# exit
```

Using this, we execute (`exec`) into the pod in interactive mode (`-i`) while opening a tty (`-t`)
and execute a shell (`sh`).

> Note that the exec automatically executes into the correct container (`cache-redis-cluster`). We
> could also have specified it using the `-c` flag.

Once inside the container, we can check with `ps aux ww` which PID is associated with the
`redis-server` process. As we can see, it is the PID 1.

Hence you can execute the following, to continuously kill the process:

```
while true; do
  kubectl -n user-0 exec cache-redis-cluster-5 -c cache-redis-cluster -- kill 1
  echo "killed"
  sleep 1;
done
```

You should see that the pod no longer is marked as "Ready":

```
$ kubectl -n user-0 get pod cache-redis-cluster-5
NAME                    READY   STATUS             RESTARTS   AGE
cache-redis-cluster-5   1/2     CrashLoopBackOff   3          81m
```

Now wait for about one minute and check the Alertmanager. Once you see the alert appear, kill the
loop you created. Note that the pod will not restart straight away, since it is in a
CrashLoopBackOff. In order to force a restart, delete the pod (it will be recreated by the
StatefulSet directly):

```
$ kubectl -n user-0 delete pod cache-redis-cluster-5
pod "cache-redis-cluster-5" deleted
```

Then after a short time, the alert should disappear again from the Alertmanager.

</details>
