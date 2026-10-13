---
name: sophos-firewall-v23
description: Create IPv4 firewall policy rules on Sophos Firewall v23 through its REST API. Use when asked to add or configure a v23 firewall rule; do not use for NAT, routes, VPN, or interface changes.
allowed-tools: shell
---

# Sophos Firewall v23 Rule Skill

Use this skill to plan, review, create, and verify IPv4 firewall policy rules on a Sophos Firewall v23 appliance through the Firewall Configuration REST API.

## Scope and safety

- Handle IPv4 firewall policy rules only. Do not change IPv6 rules, NAT rules, routes, VPN settings, firewall interfaces, zones, or LAN/WAN interface configuration.
- Never create, update, or delete LAN or WAN interfaces or their settings. Refer to existing zones and objects in a rule without modifying them.
- Never modify or delete existing firewall rules. If the requested behavior requires changing an existing rule, stop and explain why instead of working around it with a broader or duplicate rule.
- Treat firewall writes as live configuration changes. Before any write, show the target firewall, each rule and supporting object to be created, the proposed order, and the expected traffic effect. Ask for explicit user confirmation. Do not treat a request to create a rule as confirmation of a specific plan if details remain unresolved.
- Never expose, print, commit, or persist API keys. Use a user-approved secret source; do not place credentials in command arguments, files, or logs. Do not disable TLS verification to work around certificate errors.
- If the API version, target firewall, authorization, requested traffic, or rule placement cannot be verified, stop before making changes and report the blocker.

## Workflow

### 1. Establish the target and API

1. Confirm the target firewall and that its REST configuration API is v23-compatible. Use the supplied or locally available v23 OpenAPI document as the source of truth for endpoint paths, request bodies, validation, and response codes.
2. Use the API base URL format `https://<firewall-hostname>:<port>/api/firewall-config/v1`; the IPv4 firewall-rule collection is `GET`/`POST /firewall/rules/ipv4`.
3. Authenticate with the API's bearer-token mechanism using a secret source approved by the user. Do not echo the token or include it in shell history.
4. Do not proceed through a TLS verification failure by using insecure curl options. Resolve certificate trust or report the blocker.

### 2. Translate and inspect

1. Resolve the requested rule into an explicit action (`accept`, `drop`, or `reject`), source zone and network, destination zone and network, services, enabled state, intended position, and purpose. Ask about missing or ambiguous traffic criteria.
2. Read all pages of existing IPv4 rules with `GET /firewall/rules/ipv4`, including pagination metadata. Always refresh the complete live rule list immediately before suggesting a change to an existing rule; do not base advice on a cached or earlier list. Refresh it again immediately before any write. Include the verified current positions and relevant settings in the impact assessment.
3. Read relevant existing zones, address objects, and services using their documented v23 API endpoints. Reuse compatible objects by exact name; do not assume a similarly named object has the intended contents.
4. If a required object is missing, propose its exact definition. Do not create it until it is included in the user's explicit approval of the write plan. Do not alter existing objects.
5. Determine the necessary rule order from current policy semantics. If correct enforcement would require moving, editing, or deleting an existing rule, stop and explain the limitation.
6. Assess the broader policy context before describing overlap or suggesting that a rule be deleted or updated. Inspect all relevant matching rules and their order, enabled state, zones, networks, services, referenced objects, and security/logging behavior such as IPS, web and application policies, inspection, QUIC handling, and traffic logging. Determine what traffic the rule currently permits or blocks, what would match next if it changed, and whether other policies or objects depend on it. Do not call rules equivalent or recommend deletion/update based only on matching traffic criteria. Explain the likely access, security, and logging impact; if the full effect cannot be established, do not recommend the change.

### 3. Name and describe every rule

Use this readable naming pattern:

`<ACTION>-<PURPOSE>-<SOURCE>-TO-<DESTINATION>-<SERVICE>`

- Use uppercase ASCII words separated by hyphens. Keep the name concise and specific to the traffic and intent (for example, `ALLOW-CORP-SERVERS-TO-INTERNET-SMTP`).
- Check for an existing exact name before creation. Do not silently reuse a name for different traffic.
- The v23 schema allows firewall-rule names up to 60 characters and descriptions up to 255 characters. Respect the schema's `sfos-object-name` rules; shorten meaningful segments when needed, and stop if no clear unique name fits.
- Always set the rule's `description` field to a concise, human-readable explanation of its purpose and traffic scope, including the action, source, destination, and service. Do not leave it blank or use a generic placeholder. Example: `Allow SMTP from approved corporate mail servers to the internet for outbound email delivery.`

### 4. Review, confirm, and apply

Before writing, present a concise change plan that includes:

- Firewall hostname and API version (never the API key).
- The exact rule name, description, action, source/destination zones and networks, services, enabled state, and position.
- Any supporting objects and their exact definitions.
- Relevant existing-rule matches and the expected effect on traffic.

Ask the user to explicitly confirm this exact plan. If the plan changes after confirmation, request confirmation again.

After confirmation:

1. Create only the approved missing supporting objects, using the v23 schema and documented endpoints. Read each object back and verify its definition before referencing it.
2. Create the firewall rule with `POST /firewall/rules/ipv4` and `ruleType: "firewall"`. Include a non-empty meaningful `description` and the approved `position`. Follow the exact schema and accepted names for all other fields.
3. Require the documented success response (typically HTTP `201`) and inspect the returned rule.
4. Read the rule list back, following all pages. Verify the created rule's values and relative position against relevant existing rules. Confirm no interfaces or existing rules were changed.
5. If a write times out or returns an ambiguous result, read back actual state before retrying; never blindly repeat a potentially successful POST. If verification fails, report the discrepancy and stop rather than claiming success.

## Reporting

After the operation, report the rule name and description, the firewall it was added to, the verified order/effect, and any unresolved limitation. When diagnosing rule hits or logs, distinguish a rule that is shadowed by an earlier match from one with traffic logging disabled. Never include credentials or unnecessary sensitive network details.
