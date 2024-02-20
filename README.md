# Terraform Enterprise (TFE) on Single-Node OpenShift (SNO)

This repo is my successful attempt to get TFE installed on OpenShift. I did
this in a lab using Single-Node OpenShift, which is a mostly complete OpenShift
deployment on a single server.

TFE installs on Kubernetes from a Helm chart. TFE has 3 dependencies. For this
example, I ran all three on OpenShift.

| Dependency | What I'm using |
| ---------- | -------------- |
| PostgreSQL-compatible database | [OpenShift Helm Charts - postgresql-persistent - 0.0.3] |
| Redis instance | [OpenShift Helm Charts - redis-persistent - 0.0.2] |
| S3-compatible object storage | [MinIO on SNO] |

All three dependencies require Kubernetes persistent storage. SNO notably does
not come out of the box with any persistent storage configured. I used
[SNO Local Path Provisioner] to provide a StorageClass for automatic
provisioning of PersistentVolumes.

## Important Notes

* I performed this installation on a fresh OpenShift 4.12 SNO deployment.
* The Helm chart that deploys TFE is not in this repo. It is hosted in a Helm registry I'm referencing. The source code is available [here][TFE Helm Chart Source Code].
* Redis and PostgreSQL in this example deployment do not use HTTPS. **(They absolutely should outside of a lab!)**
* `TFE_HOSTNAME` MUST match the DNS name on the Route in OpenShift.
* Providing a certificate in the Helm chart is required. There doesn't appear to be a way to serve over HTTP in-cluster and perform Edge termination on cluster ingress at the OpenShift load balancer.
* I set up a valid HTTPS certificate the for cluster's ingress. I'm not sure what affect a self-signed certificate would have.
* The TFE container image is over 4 GB in file size.
* The TFE container image will only run in OpenShift if the `anyuid` SCC is granted to the Service Account that runs the container (`terraform-enterprise`).
* The Red Hat Redis 6 image doesn't appear to support a username, only a password.
* `TFE_OBJECT_STORAGE_S3_REGION` is required to be set, although the value doesn't matter if you have `TFE_OBJECT_STORAGE_S3_ENDPOINT` set.
* If you experience issues that reinstalling TFE doesn't fix, you may need to blow away the database and object-storage bucket.

## References

* [TFE Helm Chart Source Code]
* [TFE Kubernetes Documentation - Requirements]
* [TFE Kubernetes Documentation - Installation]

## Installation

### Install sno-local-path-provisioner to provide persistent storage

**NOTE: Do not uninstall this!**

```bash
make -C charts/sno-local-path-provisioner install
```

It will take 5 minutes to deploy. Once `oc get co` returns all cluster operators are healthy, continue to next step.

### Create a project for Terraform Enterprise (and dependencies)

```bash
oc new-project terraform-enterprise
```

### Install MinIO

```bash
# !!! EDIT charts/sno-minio-deployment/values.yaml - Replace DNS names with your own !!!
make -C charts/sno-minio-deployment install
```

* Go to MinIO console URL (mine is https://minio.apps.hub.taco.moe/)
* Use access key and secret access key as the username/password
* Create a bucket named `terraform-enterprise`

### Install PostgreSQL

```bash
make -C charts/postgresql-persistent install
```

### Install Redis

```bash
make -C charts/redis-persistent install
```

### Create pull secret

```bash
kubectl create secret docker-registry terraform-enterprise \
  --docker-server=images.releases.hashicorp.com \
  --docker-username=terraform \
  --docker-password="$(cat terraform.hclic)" \
  --namespace terraform-enterprise
```

### Add anyuid SCC

OpenShift uses Security Context Constraints to determine what a given container
user is allowed to do. Service Accounts that run containers in OpenShift will
by default have the *restricted* SCC assigned, which disables running as a
specific user id.

OpenShift supports a *nonroot* SCC, which allows the container to run as any
non-root (not user id 0) user. I couldn't get it working with user 1000 or any
other non-root user.

I did get it working with *anyuid* SCC, which allows any user id to run the
container, including root (user id 0).

```bash
oc adm policy add-scc-to-user anyuid system:serviceaccount:terraform-enterprise:terraform-enterprise
```

### Add secrets

Copy the *secrets_template.yaml* file to *secrets.yaml*. Replace the
certificate/key/ca info and the environment secrets. Also add the Hashicorp
licence info.

```bash
cp secrets_template.yaml secrets.yaml
# !!! EDIT secrets.yaml - Replace info with your own !!!
```

### Install TFE

```bash
make install
```

### Expose TFE outside of the cluster

```bash
oc create -f route.yaml
```

## Troubleshooting

### Validate PostgreSQL connection

https://stackoverflow.com/a/44496546

```bash
pg_isready -d <db_name> -h <host_name> -p <port_number> -U <db_user>
```

### Validate Redis connection

https://stackoverflow.com/a/53056705

```bash
redis-cli -h 127.0.0.1 -p 6379 -a '<password>' 
```

## Uninstall

```bash
make uninstall
make -C charts/sno-minio-deployment uninstall
make -C charts/postgresql-persistent uninstall
make -C charts/redis-persistent uninstall
oc delete project terraform-enterprise
oc adm policy remove-scc-from-user anyuid system:serviceaccount:terraform-enterprise:terraform-enterprise
```

[MinIO on SNO]: https://github.com/RyanMillerC/sno-minio-deployment/
[OpenShift Helm Charts - postgresql-persistent - 0.0.3]: https://github.com/openshift-helm-charts/charts/tree/main/charts/redhat/redhat/postgresql-persistent/0.0.3/src
[OpenShift Helm Charts - redis-persistent - 0.0.2]: https://github.com/openshift-helm-charts/charts/tree/main/charts/redhat/redhat/redis-persistent/0.0.2/src
[OpenShift Helm Charts]: https://github.com/openshift-helm-charts/charts
[SNO Local Path Provisioner]: https://github.com/RyanMillerC/sno-local-path-provisioner
[TFE Helm Chart Source Code]: https://github.com/hashicorp/terraform-enterprise-helm
[TFE Kubernetes Documentation - Installation]: https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/kubernetes/install
[TFE Kubernetes Documentation - Requirements]: https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/kubernetes/requirements
