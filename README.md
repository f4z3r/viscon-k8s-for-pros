# Kubernetes Monitoring for Pros

This document serves as a reference for the practical part of the VISCon 2021 Workshop "Achieve
99.999% Service Availability Like a Pro".

## Setup

You all have a single namespace on which you can act. These namespaces are named `user-n`. You will
not have restricted access to the cluster to make the setup simpler. However, please do not act on
any resources outside your namespace as it might interfere with other peoples work.

## Practical Exercises

There are two parts to the practical exercises of the workshop. During the first part, you will
deploy a simple application with Kubernetes. This should provide you with a small introduction to
how Kubernetes works, and how deployments can be configured. You will also get an overview on how
Kubernetes handles container management for you, and how it can already drastically improve the
availability of your applications out of the box. Finally you will get some hands-on experience on
how Kubernetes allow you to further improve how you deploy your applications to make them even more
resilient to temporary issues.

During the second part, you will get to solve various challenges with Prometheus, Grafana, and
Alertmanager in order to build up knowledge on how applications can be monitored in production.

