# CIDR exclusions

Open Settings → Split Tunneling → IP ranges / CIDR.

Add IPv4 or IPv6 networks such as `127.0.0.0/8`, `::1/128`, or `192.168.1.0/24`.
Matching destinations connect directly while Split Tunneling is enabled.
The existing split-tunnel policy is respected. The app exposes the default exclude policy.

Import accepts UTF-8 TXT files (one CIDR per line, optional comma separation and
`#` comments) and JSON. Imports merge with existing networks. Host bits are
masked and duplicate networks are removed. All entries are validated before
one backend request persists the batch. Domain and application filters are preserved.
Files are limited to 1 MiB and lists to 10,000 entries.

Export supports TXT and this versioned JSON format:

```json
{
  "version": 1,
  "type": "lantern-cidr-excludes",
  "cidrs": ["127.0.0.0/8", "::1/128"]
}
```

The backend maintains a generated resolver gate alongside `split-tunnel.json`.
When split tunneling is enabled and CIDRs exist, domain destinations are resolved
through the VPN DNS transport before address matching. Without active CIDRs,
the resolver gate is inert and normal fake-IP routing is preserved.
Direct IP connections do not need a DNS lookup.

## Cloud builds

The **CIDR Windows installer** workflow builds and tests on GitHub-hosted runners.
It checks out the exact backend commit recorded in the workflow next to this
repository; `go.mod` uses that sibling checkout. No local SDK installation is needed.

Successful runs upload the Windows installer and a ZIP of the complete application
folder. This personal fork is unsigned. The installer includes the native service
and stages the Visual C++ runtime required by the selected MSVC toolchain.
