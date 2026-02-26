# Pulumi OIDC Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/plugins) that exchanges a [Buildkite OIDC token](https://buildkite.com/docs/pipelines/security/oidc) for a [Pulumi access token](https://www.pulumi.com/docs/pulumi-cloud/oidc/client/) using OAuth 2.0 Token Exchange.

The resulting token is exported as `PULUMI_ACCESS_TOKEN`, allowing subsequent pipeline steps to authenticate with Pulumi Cloud without storing static credentials.

## Prerequisites

- **Buildkite agent v3.48+** (OIDC token support)
- `curl` >= 8.0.0
- `jq` >= 1.5 (for `-e` exit status flag)
- `bash` >= 4.0
- A Pulumi Cloud organization with OIDC configured (see setup below). Available [token types depend on your Pulumi edition](https://www.pulumi.com/docs/administration/access-identity/oidc-client/#token-types-by-edition):
  - **Individual**: personal tokens only
  - **Team**: personal and organization tokens
  - **Enterprise / Business Critical**: personal, organization, and team tokens

## Pulumi Cloud Setup

Before using this plugin, you need to register Buildkite as an OIDC issuer in Pulumi Cloud and create an authorization policy.

### 1. Register Buildkite as an OIDC Issuer

1. Navigate to **Pulumi Cloud** > **Access Management** > **Settings** > **OIDC Issuers**
2. Click **Register a new issuer**
3. Set the issuer URL to `https://agent.buildkite.com`
4. Configure the max token expiration as needed

See the [Pulumi OIDC client documentation](https://www.pulumi.com/docs/pulumi-cloud/oidc/client/) for details.

### 2. Create an Authorization Policy

By default, all token exchange requests are denied. You must create an authorization policy that matches the Buildkite OIDC token claims.

Buildkite OIDC tokens use the following subject claim format:

```
organization:{ORG_SLUG}:pipeline:{PIPELINE_SLUG}:ref:{REF}:commit:{COMMIT}:step:{STEP_KEY}
```

Example policy allowing all pipelines in a Buildkite organization:

- **Sub claim**: `organization:my-buildkite-org:pipeline:*:ref:*:commit:*:step:*`
- **Token type**: Organization access token
- **Scope**: (leave empty for default)

## Configuration

### Required

#### `org_name` (string)

The Pulumi organization name. Used to construct the audience (`urn:pulumi:org:<org_name>`) for both the Buildkite OIDC token request and the Pulumi token exchange.

### Optional

#### `lifetime` (number)

The lifetime (in seconds) for the Buildkite OIDC token before it expires. Must be a non-negative integer. When set to `0` (the default), the API uses its default lifetime.

Default: `0`

#### `requested_token_type` (string)

The type of Pulumi access token to request. Must be one of:

| Value | Description |
|-------|-------------|
| `urn:pulumi:token-type:access_token:organization` | Organization-scoped token (default) |
| `urn:pulumi:token-type:access_token:team` | Team-scoped token (requires `scope`) |
| `urn:pulumi:token-type:access_token:personal` | Personal token (requires `scope`) |

Default: `urn:pulumi:token-type:access_token:organization`

#### `scope` (string)

Scope for the requested token. The value depends on the `requested_token_type`:

| Token Type | Scope Format | Example |
|------------|-------------|---------|
| Organization | `admin` (optional, for admin privileges) | `admin` |
| Team | `team:<TEAM_NAME>` | `team:platform-team` |
| Personal | `user:<USER_LOGIN>` | `user:jane` |

The authorization policy must explicitly grant the requested scope.

#### `debug` (boolean)

When `true`, prints the full curl command and API response for troubleshooting. **Warning**: this exposes both the Buildkite OIDC token and the Pulumi access token in the build log. Only use for debugging.

Default: `false`

## Output

On success, the plugin exports:

- **`PULUMI_ACCESS_TOKEN`** - A short-lived Pulumi access token that authenticates subsequent `pulumi` CLI commands.

## Examples

### Minimal: organization access token

```yaml
steps:
  - label: ":pulumi: Deploy"
    command: "pulumi up --yes --stack my-org/my-stack/production"
    plugins:
      - instant-labs/pulumi-oidc#v0.1.0:
          org_name: "my-org"
```

### Team-scoped access token

```yaml
steps:
  - label: ":pulumi: Deploy"
    command: "pulumi up --yes --stack my-org/my-stack/production"
    plugins:
      - instant-labs/pulumi-oidc#v0.1.0:
          org_name: "my-org"
          requested_token_type: "urn:pulumi:token-type:access_token:team"
          scope: "team:platform-team"
```

### Personal access token with custom lifetime

```yaml
steps:
  - label: ":pulumi: Deploy"
    command: "pulumi up --yes --stack my-org/my-stack/production"
    plugins:
      - instant-labs/pulumi-oidc#v0.1.0:
          org_name: "my-org"
          requested_token_type: "urn:pulumi:token-type:access_token:personal"
          scope: "user:jane"
          lifetime: 3600
```

### With Pulumi ESC for cloud credentials

After obtaining a Pulumi access token via this plugin, you can use [Pulumi ESC](https://www.pulumi.com/docs/esc/) to dynamically fetch cloud provider credentials:

```yaml
steps:
  - label: ":pulumi: Deploy with ESC"
    commands:
      - eval $(pulumi env open my-org/my-project/aws-prod --format shell)
      - pulumi up --yes --stack my-org/my-stack/production
    plugins:
      - instant-labs/pulumi-oidc#v0.1.0:
          org_name: "my-org"
```

This uses your Pulumi access token to open an ESC environment that provides temporary AWS/Azure/GCP credentials via OIDC federation. See [Configuring OIDC in ESC](https://www.pulumi.com/docs/esc/environments/configuring-oidc/) for environment setup.

## References

- [Pulumi OIDC Client Integration](https://www.pulumi.com/docs/pulumi-cloud/oidc/client/)
- [Buildkite OIDC](https://buildkite.com/docs/pipelines/security/oidc)
- [Pulumi ESC](https://www.pulumi.com/docs/esc/)
- [Using Buildkite with Pulumi](https://www.pulumi.com/docs/iac/guides/continuous-delivery/buildkite/)

## Development

Run tests:

```bash
make test
```

Run linter:

```bash
make lint
```

## License

MIT License. See [LICENSE](https://opensource.org/licenses/MIT).
