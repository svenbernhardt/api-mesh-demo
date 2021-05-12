# Cloud-native apps with API Gateway and Service Mesh

- [Cloud-native apps with API Gateway and Service Mesh](#cloud-native-apps-with-api-gateway-and-service-mesh)
  - [Prepare the environment](#prepare-the-environment)
    - [Bootstrap the environment automatically](#bootstrap-the-environment-automatically)
    - [Bootstrap the environment manually](#bootstrap-the-environment-manually)
  - [Initial configuration](#initial-configuration)
  - [API Gateway configuration](#api-gateway-configuration)
    - [Expose Marketplace app using ingress](#expose-marketplace-app-using-ingress)
    - [Working with plugins](#working-with-plugins)
  - [Mesh configuration](#mesh-configuration)
    - [Enable mTLS](#enable-mtls)
    - [Enable Traffic Traces](#enable-traffic-traces)
      - [Base setup](#base-setup)
      - [Adjust the Mesh](#adjust-the-mesh)

The following hands-on descriptions guides you on your Cloud-native journey by improving Cloud-native architectures leveraging concepts like API Gateway and Service Mesh for ensuring connectivity, security and observability.

The following scenario description uses [k3d](https://github.com/rancher/k3d) as a runtime platfrom, but in general you can use any Kubernetes distro you like.

As example application, the [Kuma Demo Application](https://github.com/kumahq/kuma-demo) is used. 

## Prepare the environment

### Bootstrap the environment automatically

The demo environment can be easily provisioned by using the _bootstrap_demo.sh_ script.

If you want to use another Kubernetes Distro you can also follow the manual setup steps mentioned in the next section.

### Bootstrap the environment manually

- Setup K3d Cluster

```bash
k3d cluster create mesh-demo --api-port 127.0.0.1:6445 --servers 1 --agents 2 --port '8088:80@loadbalancer' --k3s-server-arg '--no-deploy=traefik'
```

- Install marketplace application

```bash
kubectl apply -f https://bit.ly/demokuma
```

- Install Kuma Control Plane

```bash
kumactl install control-plane | kubectl apply -f -
```

*Note:* Before you can use kumactl CLI, you need to install the current version as described in the corresponding [documentation](https://kuma.io/docs/1.1.5/installation/kubernetes/).

After installing the Kuma Control Plane, it can be accessed using a browser, after port-forwarding the kuma-control-plane service:

```bash
kubectl port-forward svc/kuma-control-plane -n kuma-system 5681
```

## Initial configuration

First of all, we need to add the pods of the marketplace app to the mesh.

- Setup Data plane proxies for the Marketplace application

```bash
kubectl apply -f k8s/01-connect-dp.yaml && kubectl delete pod --all -n kuma-demo
```

To be able to access the Marketplace application from outside Kubernetes, we need to expose the Frontend pod. In Kubernetes, we can use Ingress for doing so. Kong API Gateway can be configured to act as an Ingress Controller, which is done in the next step.

- Add API Gateway to the stack

As a first step, Kong for Kubernetes must be deployed using the following command:

```bash
kubectl apply -f https://bit.ly/demokumakong
```

Afterwards, we can configure the API Gateway, expose respective services and configure policies, e.g. for authenticating users.

## API Gateway configuration

### Expose Marketplace app using ingress

As we now have an API Gateway in place, the Marketplace app should be exposed using an Ingress rule, so that port-forwarding is no longer needed.

```bash
kubectl apply -f k8s/02-ingress-frontend.yaml -n kuma-demo
```

### Working with plugins

In a first step, we'll add Kong Basic Auth Plugin to achieve simple authentication for the Marketplace app without changing the code base.

```bash
kubectl apply -f k8s/07-kong-basic-auth-plugin.yaml

kubectl apply -f k8s/08-kong-consumer.yaml

kubectl apply -f k8s/09-ingress-frontend_with_plugin.yaml
```

The commands above create a Kong Basic Auth Plugin, a Kong Consumer and update the already configured Ingress definition.

In addition, we need to create a respective K8s Secret that can be used for the consumer to authenticate. In case of Kong Basic Auth plugin this is simply a String-based password.

```bash
kubectl create secret generic yoda-basicauth  \
  --from-literal=kongCredType=basic-auth  \
  --from-literal=username=yoda \
  --from-literal=password=s3cret
```

## Mesh configuration

### Enable mTLS

mTLS is used to secure the communication between the Services within our Mesh. Additionally, after enabling mTLS, it needs to be specified, which Services are allowed talking to each other.

*Note:* Beforehand, the default Traffic permission that is defined for the Mesh default should be deleted, because it allows all traffic between all Services.

```bash
kubectl delete trafficpermission allow-all-default
```

Enabling mTLS is done by changing the Meshes configuration:

```bash
kubectl apply -f k8s/03-mesh-add-mtls.yaml
```

After executing the command above the marketplace app is no longer working properly. To solve this situation, respective traffic permissions need to be defined.

```bash
kubectl apply -f k8s/04-traffic-permissions.yaml
```

Now the marketplace app is again as before; but now, the services are communicating securely with each other.

### Enable Traffic Traces

Insights into highly distributed applications are necessary to being able to continuously improve and maintain applications. Observability is key; Observability builds upon the three pillars Logging, Metrics and Traces.

By enabling Traffic Traces, traces for all Dataplane Proxies can be collected. As tracing operates on HTTP layer, only traces for HTTP-based proxies are collected. Respective services needs to be annotated accordingly.

Example:

```bash
80.service.kuma.io/protocol: http
```

#### Base setup

Before the Mesh configuration can be adjusted, the respective Tracing ifnrastructure needs to be setup. Per default Kuma uses Jaeger for Service Tracing.

```bash
kumactl install tracing | kubectl apply -f -
```

After installing Jaeger, Jaeger UI can be accessed using a browser, after port-forwarding the corresponding service port:

```bash
kubectl port-forward svc/jaeger-query -n kuma-tracing 16686:80
```

#### Adjust the Mesh

To enable Traffic traces in the Mesh, the respective configuration needs to be adjusted.

```bash
kubectl apply -f k8s/05-mesh-add-tracing.yaml
```

In addition, a Traffic trace policy needs to be defined.

```bash
kubectl apply -f k8s/06-traffic-trace-all.yaml
```

This policy traces all traffic within the Mesh.
