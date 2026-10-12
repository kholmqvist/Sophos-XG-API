---
name: blackhole-remove
description: Remove an IP address or CIDR network from the Sophos XG blackhole route lists and delete the route from all firewalls via the XML API. Use this skill when asked to unblock, remove, or un-blackhole a network/IP.
allowed-tools: shell
---

# Blackhole Remove Skill

Use this skill to remove an IP address or CIDR network from the blackhole lists and delete the corresponding route from all firewalls.

## Firewall inventory

| Firewall | API version | Env var prefix |
|----------|-------------|----------------|
| FREJA    | 2105.1 (v21.5MR2) | `SOPHOS_FREJA_*` |
| ODENSE   | 2200.1 (v22MR1)   | `SOPHOS_ODENSE_*` |
| INDIA    | 2105.1 (v21.5MR2) | `SOPHOS_INDIA_*` |
| THAILAND | 2200.1 (v22MR1)   | `SOPHOS_THAILAND_*` |
| ENGLAND  | 2105.1 (v21.5MR2) | `SOPHOS_ENGLAND_*` |
| USA      | 2105.1 (v21.5MR2) | `SOPHOS_USA_*` |

## Step-by-step process

### 1. Locate the entry

Search both `blackhole.txt` and `blackhole_bruteforce.txt` for the exact network. If the IP is not a direct match, check whether it is covered by a wider subnet entry and report that to the user.

### 2. Remove the entry from the file

Delete the matching line from the file. Re-sort if needed to keep entries numerically ordered by IP.

### 3. Delete the route from each firewall via the XML API

Use `op run` to inject credentials and call the API for each firewall.

**API endpoint:** `https://<host>:4444/webconsole/APIController`
**Method:** POST with `reqxml=<payload>`

#### Payload — v22MR1 firewalls (ODENSE, THAILAND)

Minimal form is sufficient:
```xml
<Request>
  <Login>
    <Username>USER</Username>
    <Password>PASS</Password>
  </Login>
  <Remove>
    <UnicastRoute>
      <DestinationIP>A.B.C.D</DestinationIP>
      <Netmask>N.N.N.N</Netmask>
    </UnicastRoute>
  </Remove>
</Request>
```

#### Payload — v21.5MR2 firewalls (FREJA, INDIA, ENGLAND, USA)

Full route object is required:
```xml
<Request>
  <Login>
    <Username>USER</Username>
    <Password>PASS</Password>
  </Login>
  <Remove>
    <UnicastRoute>
      <IPFamily>IPv4</IPFamily>
      <DestinationIP>A.B.C.D</DestinationIP>
      <Netmask>N.N.N.N</Netmask>
      <Interface>Blackhole</Interface>
      <Blackhole>Enable</Blackhole>
      <Distance>0</Distance>
      <AdministrativeDistance>1</AdministrativeDistance>
      <Status>ON</Status>
      <Description>ORIGINAL_DESCRIPTION</Description>
    </UnicastRoute>
  </Remove>
</Request>
```

> **Note:** The `<Description>` value must match what was set when the route was added (e.g. `Blackhole Datacamp Limited (AS212238) 2026-05-29`). If the exact description is unknown, first query the routes with a `<Get><UnicastRoute></UnicastRoute></Get>` request to find the matching entry and retrieve its description.

A successful response contains:
```xml
<Status code="200">Configuration applied successfully.</Status>
```

A `code="500"` response usually means the route does not exist on that firewall — this is acceptable.

#### CIDR to subnet mask conversion

| CIDR | Netmask |
|------|---------|
| /32  | 255.255.255.255 |
| /24  | 255.255.255.0 |
| /23  | 255.255.254.0 |
| /22  | 255.255.252.0 |
| /21  | 255.255.248.0 |
| /20  | 255.255.240.0 |
| /19  | 255.255.224.0 |
| /18  | 255.255.192.0 |
| /17  | 255.255.128.0 |
| /16  | 255.255.0.0 |

For other prefix lengths: `netmask = 256 - 2^(8 - (cidr % 8))` in the relevant octet.

#### Example shell snippet

```bash
OP_BIOMETRIC_UNLOCK_ENABLED=true op run --env-file=.env -- bash -c '
for fw in FREJA ODENSE INDIA THAILAND ENGLAND USA; do
  host=${!SOPHOS_${fw}_HOST:-}
  user=${!SOPHOS_${fw}_USERNAME:-}
  pass=${!SOPHOS_${fw}_PASSWORD:-}
  [ -z "$host" ] && echo "[SKIP] $fw" && continue
  url="https://${host}:4444/webconsole/APIController"
  # Use appropriate payload for this firewall version
  resp=$(curl -sS -k --max-time 30 -X POST "$url" -d "reqxml=PAYLOAD")
  if printf "%s" "$resp" | grep -q "200"; then
    echo "[OK] $fw"
  else
    echo "[FAIL/SKIP] $fw: $resp"
  fi
done
'
```

### 4. Commit the change

After a successful removal, commit the updated file:
```
blackhole: remove 45.134.0.0/16 (unblocking user home IP)
```

Include the Co-authored-by Copilot trailer in the commit.
