---
name: blackhole-add
description: Add one or more IP addresses or CIDR networks to the Sophos XG blackhole route lists and push them to all firewalls. Use this skill when asked to block, blackhole, or add a network/IP to the firewall blacklist.
allowed-tools: shell
---

# Blackhole Add Skill

Use this skill to add IP addresses or CIDR networks to the Sophos XG blackhole route lists and push them live to all firewalls.

## Firewall inventory

Firewalls: **FREJA**, **ODENSE**, **INDIA**, **THAILAND**, **ENGLAND**, **USA**

## Which file to use

- **`blackhole_bruteforce.txt`** — VPN brute-force source networks and attacker IPs seen in VPN portal auth logs.
- **`blackhole.txt`** — General suspicious or malicious networks not related to VPN brute-force.

If uncertain, ask the user which file to use.

## Step-by-step process

### 1. Determine the correct CIDR

If a bare IP was given with no prefix length, default to `/32`.

### 2. Check for duplicates and overlaps

Before adding, scan both `blackhole.txt` and `blackhole_bruteforce.txt` for:
- An **exact match** of the network being added.
- Any **existing entry that already covers** the new network (i.e. the new CIDR is a subnet of an existing entry).
- Any **existing entry that would be made redundant** by the new (wider) network.

If an overlap is found, report it to the user and ask how to proceed before making any changes.

### 3. Add the entry to the correct file

Append the new entry in the format:
```
A.B.C.D/prefix  # Description (source/reason)
```

Entries must be **sorted numerically by IP address** within the file. Insert at the correct position.

For brute-force entries, add them under the most recent dated section header (e.g. `# --- Added YYYY-MM-DD ---`), or create a new dated section at the bottom if needed.

### 4. Push to all firewalls using a temporary file

Do **not** re-push all routes. Create a temporary file with only the new entries and use `BLACKHOLE_FILE` to push just those:

```bash
TMPFILE=$(mktemp /tmp/blackhole-new-XXXXXX.txt)
echo "A.B.C.D/prefix  # Description" > "$TMPFILE"
OP_BIOMETRIC_UNLOCK_ENABLED=true BLACKHOLE_FILE="$TMPFILE" op run --env-file=.env -- ./blackhole.sh
rm "$TMPFILE"
```

### 5. Commit the change

After a successful push, commit the updated blackhole file with a concise message, for example:
```
blackhole: add 45.134.0.0/16 (Datacamp Limited, AS212238)
```

Include the Co-authored-by Copilot trailer in the commit.
