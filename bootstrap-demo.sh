#! /bin/bash

k3d cluster create mesh-demo --api-port 127.0.0.1:6445 --servers 1 --agents 2 --port '8088:80@loadbalancer' --k3s-server-arg '--no-deploy=traefik'

kubectl apply -f https://bit.ly/demokuma

kumactl install control-plane | kubectl apply -f -

kumactl install tracing | kubectl apply -f -

sleep 20

kubectl port-forward svc/kuma-control-plane -n kuma-system 5681