# Defender for Containers — Alert → Sentinel Incident Demo

A demo of the platform's *runtime* detection layer: Microsoft Defender for
Containers (`modules/defender`) raises a security alert, which flows into
Microsoft Sentinel (`modules/sentinel`'s workspace onboarding) as an incident
— completing the chain `Defender → Log Analytics → Sentinel` for a threat
that Kyverno/admission control doesn't cover (it happens *after* a container
is already running).

## Recommended path — Defender's built-in "Sample alerts" ($0, safe, ~2 min)

Microsoft Defender for Cloud ships a feature specifically for demos like this:
it generates **synthetic alerts** for each enabled plan, including Containers,
without running any real workload or attack pattern. This is the supported,
documented way to demo Defender → Sentinel without cost or risk.

1. Portal → **Microsoft Defender for Cloud** → **Security alerts**
2. Click **Sample alerts** (top toolbar)
3. Select **Subscription** = your subscription, **Defender plan** = `Containers`
4. Click **Create sample alerts**
5. Wait ~1-2 minutes, then refresh **Security alerts** — you'll see entries
   such as *"Suspicious request to the Kubernetes Dashboard"* or *"A
   privileged container detected"*, tagged with MITRE ATT&CK techniques
6. Portal → **Microsoft Sentinel** → `law-ztp` → **Incidents** — the same
   alerts appear as incidents (Defender for Cloud is a built-in Sentinel data
   connector, on by default once `azurerm_sentinel_log_analytics_workspace_onboarding`
   is provisioned)
7. Open one incident and screenshot the **MITRE ATT&CK** tags on the alert —
   this is the same "alert → incident → technique" chain as the
   [Kyverno incident response demo](INCIDENT_RESPONSE_DEMO.md), but sourced
   from runtime detection instead of admission control

## Optional — a real (benign) trigger ($0, ~5 min, needs the Defender agent)

If you want one alert that came from an actual pod rather than a synthetic
sample: Defender for Containers' runtime sensor flags processes commonly
associated with cryptomining or container escape tooling by name/behavior.
Running a pod that briefly executes a binary named like a known miner (without
it actually mining anything) is enough to trigger *"Container with a miner
image"*-style detections in some configurations:

```bash
kubectl run defender-trigger -n workload-demo --image=alpine:3.20 --restart=Never \
  --command -- sh -c "echo 'simulated suspicious process — see docs/DEFENDER_ALERT_DEMO.md' && sleep 60"
kubectl delete pod defender-trigger -n workload-demo
```

This path is **not guaranteed** to fire — it depends on which Defender
sensors are enabled and can take 10-30 minutes to surface. Use the **Sample
alerts** path above as the primary demo; treat this as a bonus if time
allows.

## Why this completes the story

The Kyverno demo shows a threat **stopped before it runs** (admission
control). This demo shows the platform also has eyes on **what's already
running** (runtime detection) — and that both paths converge on the same
Sentinel workspace, so an analyst has one place to look regardless of which
layer caught the threat.
