CILIUM

```
cni in eni mode
hubble service graph
hubble grafana dashboard
```

CLUSTER_AUTOSCALER

```
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler --namespace kube-system -f helm-deployments/cluster-autoscaler-values.yaml
```

AWS_NODE_TERMINATION_HANDLER

```
helm repo add eks https://aws.github.io/eks-charts
helm upgrade --install aws-node-termination-handler eks/aws-node-termination-handler --namespace kube-system -f helm-deployments/aws-node-termination-handler-values.yaml
```

VERTICAL_POD_AUTOSCALER

```
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/
git checkout vpa-release-0.8
./hack/vpa-up.sh
```

METRICS_SERVER

```
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server/metrics-server
```

EBS_CSI_DRIVER

```
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm upgrade -install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver --namespace kube-system -f helm-deployments/ebs-csi-driver-values.yaml
kubectl apply -f helm-deployments/storage-class.yaml
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass ebs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

TRAEFIK_INTERNAL

```
helm repo add traefik https://helm.traefik.io/traefik
helm upgrade --install traefik-internal helm-charts/traefik-helm-chart/traefik/ \
-f helm-deployments/traefik-internal-values.yaml \
--namespace traefik-internal --create-namespace

kubectl port-forward -n traefik-internal $(kubectl get pods -n traefik-internal --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000
http://localhost:9000/dashboard/#/
```

TRAEFIK_EXTERNAL

```
helm repo add traefik https://helm.traefik.io/traefik
helm upgrade --install traefik-external helm-charts/traefik-helm-chart/traefik/ \
-f helm-deployments/traefik-external-values.yaml \
--namespace traefik-external --create-namespace

kubectl port-forward -n traefik-internal $(kubectl get pods -n traefik-internal --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000
http://localhost:9000/dashboard/#/
```

LOKI

```
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki -f loki-values.yaml --namespace=loki --create-namespace
kubectl --namespace loki port-forward service/loki 3100
curl http://127.0.0.1:3100/api/prom/label
```

PROMTAIL

```
helm upgrade --install promtail grafana/promtail -f helm-deployments/promtail-values.yaml --namespace promtail --create-namespace
```

VICTORIA_METRICS_SINGLE

```
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm upgrade --install vmsingle -f helm-deployments/vmetrics-single-values.yaml \
--namespace victoria-metrics --create-namespace vm/victoria-metrics-single

export POD_NAME=$(kubectl get pods --namespace victoria-metrics -l "app=server" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace victoria-metrics port-forward $POD_NAME 8428
```

VMAGENT

```
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm upgrade --install vmagent vm/victoria-metrics-agent --namespace victoria-metrics -f vmagent-values.yaml
```

VMALERT

```
helm upgrade --install vmalert vm/victoria-metrics-alert -f helm-deployments/vmalert-values.yaml --namespace victoria-metrics
kubectl port-forward --namespace victoria-metrics service/vmalert-alertmanager 3000:9093
curl http://localhost:3000/#/status
```

NODE_EXPORTER

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install node-exporter prometheus-community/prometheus-node-exporter --namespace victoria-metrics \
-f helm-deployments/node-exporter-values.yaml
```

PROMETHEUS_ADAPTER

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter \
-f helm-deployments/prometheus-adapter-values.yaml --namespace victoria-metrics

kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1
```

TEMPO

```
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install tempo grafana/tempo -f helm-deployments/tempo-values.yaml --namespace tempo --create-namespace
```

OPENTELEMETRY_COLLECTOR

```
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector \
-f helm-deployments/opentelemetry-collector-values.yaml --namespace opentelemetry-collector --create-namespace

kubectl apply -f helm-deployments/single-binary-extras.yaml
k logs synthetic-load-generator-xxxxx
Search traceid in Explore tempo data source
```

KUBE_STATE_METRICS

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics --namespace victoria-metrics \
-f helm-deployments/kube-state-metrics-values.yaml
```

GRAFANA

```
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install grafana grafana/grafana -f helm-deployments/grafana-values.yaml --namespace=grafana --create-namespace
```

SEALED_SECRETS_CONTROLLER

```
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets -f helm-deployments/sealed-secrets.yaml --namespace kube-system

cd secrets
kubectl create secret generic mysealedsecret --dry-run --from-literal=password=somevalue -o yaml | \
 kubeseal \
 --controller-name=sealed-secrets \
 --controller-namespace=kube-system \
 --format yaml > mysealedsecret.yaml
```

KUBECOST

```
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm upgrade --install kubecost helm-charts/cost-analyzer-helm-chart/cost-analyzer --namespace kubecost --create-namespace \
-f helm-deployments/kubecost-values.yaml

kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090
```

ideal:
argocd
step-ca/bless
pinniped
github runners
cilium
managed eks nodes
