# Sophos XG Firewall - Adding a Blackhole Route via API

## XML API (v18+)

Endpoint: `/webconsole/APIController`

```xml
<Set operation="add">
  <StaticRoute>
    <Name>blackhole-test</Name>
    <DestinationNetwork>
      <NetworkType>Network</NetworkType>
      <Network>10.10.10.0/24</Network>
    </DestinationNetwork>
    <Gateway type="blackhole"></Gateway>
    <Interface></Interface>
    <AdminStatus>Enable</AdminStatus>
  </StaticRoute>
</Set>
```

### cURL Example

```bash
curl -k -X POST "https://<firewall-ip>:4444/webconsole/APIController" \
  -H "Content-Type: application/xml" \
  -H "Authorization: <api-key>" \
  -d @add_blackhole_route.xml
```

## REST API (v19+)

Endpoint: `POST /api/v2/static_route`

```json
{
  "name": "blackhole-route",
  "destination_network": "10.10.10.0/24",
  "gateway_type": "blackhole",
  "admin_status": "enable"
}
```

### cURL Example

```bash
curl -k -X POST "https://<firewall-ip>:4444/api/v2/static_route" \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d @add_blackhole_route.json
```

## Notes

- The exact API structure may vary depending on firmware version (v18, v18.5, v19, v20).
- Refer to your version's [Sophos XG API documentation](https://docs.sophos.com/nsg/sophos-firewall/20.0/API/index.html) for the latest schema.
- If "blackhole" isn't visible as a gateway type in the API docs, create a blackhole route in the UI first, then query it via the API to see how it's represented.
