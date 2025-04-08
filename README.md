# Pulumi OIDC Buildkite Plugin

A Buildkite plugin to exchange Buildkite OIDC tokens against Pulumi access tokens.

## Options

These are all the options available to configure this plugin's behavior.

### Required

#### `org_name` (string)

The Pulumi org. Needed to create the correct audience.

### Optional

#### `lifetime` (number)

The time (in seconds) the OIDC token will be valid for before expiry. Must be a non-negative integer. If the flag is omitted or set to 0, the API will choose a default finite lifetime. (default: 0)

#### `requested_token_type` (string)

The type of token it will request, one of:

    urn:pulumi:token-type:access_token:organization
    urn:pulumi:token-type:access_token:team
    urn:pulumi:token-type:access_token:personal

#### `scope` (string)

The scope to use when requesting the Pulumi access token, according to the token type:

    For personal access tokens: user:USER_NAME
    For team access tokens: team:TEAM_NAME
    For organization access tokens, the admin scope can be set to request a token with admin privileges (the authorization policy should explicitly grant the increased permissions)

#### `debug` (boolean)

Toogle to output debug information. This will print the Buildkite token as well as the exchanged Pulumi token. This allows to introspect the tokens to debug any issues.

## Examples

Show how your plugin is to be used

```yaml
steps:
  - label: "🔨 Running plugin"
    command: "echo template plugin"
    plugins:
      - pulumi-oidc#v0.1.0:
          org_name: "acme_org"
```

## And with other options as well

If you want to change the plugin behavior:

```yaml
steps:
  - label: "🔨 Running plugin"
    command: "echo template plugin with options"
    plugins:
      - pulumi-oidc#v1.0.0:
          org_name: "acme_org"
          lifetime: 3600
          requested_token_type: "urn:pulumi:token-type:access_token:team"
          scope: "team:acme_team"
          debug: true
```

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
