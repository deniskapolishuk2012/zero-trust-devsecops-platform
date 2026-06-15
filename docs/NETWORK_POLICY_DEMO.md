# NetworkPolicy Demo — Zero Trust East-West Traffic

A 5-minute, $0 demo that shows Zero Trust *inside* the cluster, not just at the
edge: a `frontend` pod can reach `backend`, but an `attacker-pod` with no
business relationship to `backend` cannot — even though both run in the same
namespace, on the same cluster, with no NSG or firewall involved.

The enforcement comes from two things already wired up by Terraform:

1. **AKS Azure CNI with `network_policy = "azure"`** (`modules/aks`) — the
   data-plane that actually enforces `NetworkPolicy` objects.
2. **Kyverno's `add-default-networkpolicy` ClusterPolicy** (`modules/kyverno`)
   — the moment `namespace-a` is created, Kyverno generates a
   `default-deny-ingress` NetworkPolicy for it automatically. Nothing in this
   demo's YAML creates that policy — it's already there.

## Step 1 — Deploy

```bash
kubectl apply -f demo/network-policy-demo/namespace.yaml
kubectl apply -f demo/network-policy-demo/backend.yaml
kubectl apply -f demo/network-policy-demo/frontend.yaml
kubectl apply -f demo/network-policy-demo/attacker-pod.yaml
```

Confirm Kyverno already generated the default-deny policy for the new
namespace:

```bash
kubectl get networkpolicy -n namespace-a
# NAME                  POD-SELECTOR   AGE
# default-deny-ingress  <none>         10s
```

At this point `backend` accepts traffic from **nobody** — including
`frontend`. Prove it:

```bash
kubectl exec -n namespace-a frontend -- curl -sS -m 3 http://backend
# curl: (28) Connection timed out after 3000 milliseconds
```

## Step 2 — Grant the one legitimate path

```bash
kubectl apply -f demo/network-policy-demo/network-policy-allow-frontend-to-backend.yaml
```

This adds a second NetworkPolicy scoped to `backend` pods, allowing ingress
only from pods labeled `app=frontend`. The default-deny policy from Step 1 is
unaffected — NetworkPolicies are additive (a pod is reachable from anything
matched by *any* applicable policy).

## Step 3 — Verify: frontend ✅, attacker ❌

```bash
# frontend -> backend: allowed by the policy from Step 2
kubectl exec -n namespace-a frontend -- curl -sS -m 3 -o /dev/null -w "%{http_code}\n" http://backend
# 200

# attacker-pod -> backend: still blocked by Kyverno's default-deny-ingress —
# attacker-pod isn't labeled app=frontend, so no policy admits it
kubectl exec -n namespace-a attacker-pod -- curl -sS -m 3 -o /dev/null -w "%{http_code}\n" http://backend
# curl: (28) Connection timed out after 3000 milliseconds
```

That side-by-side — identical command, identical target, different label —
*is* the demo. Screenshot both terminal outputs together.

## Step 4 — Teardown

```bash
kubectl delete namespace namespace-a
```

## Why this matters

Most "Zero Trust" diagrams stop at the cluster boundary: who can deploy, who
can authenticate, what image can run. This demo shows the same principle
applied to **pod-to-pod traffic** — by default, nothing can talk to anything,
and every exception is an explicit, auditable YAML object (`kubectl get
networkpolicy -A -o yaml`). Combined with `modules/kyverno`'s
auto-generation, this guarantee holds for *every future namespace* without
relying on developers to remember to write the policy themselves.
