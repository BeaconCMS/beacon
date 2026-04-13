# Beacon Admin & Authentication System Design

## Problem

Beacon has no user management, no authentication, and no authorization. The LiveAdmin is unprotected. There's no Beacon-level admin for managing the platform. The site-level admin can't distinguish between admins, editors, and viewers.

## Authentication: OpenID Connect

Beacon uses **OpenID Connect** (via the `openid_connect` hex package) as its default authentication method. This delegates login, password management, MFA, and session lifecycle to an external identity provider (Google, Auth0, Okta, Keycloak, Azure AD, etc.).

### Auth Modes

**OIDC Mode** (default for production): One or more OIDC providers configured. Login redirects to the provider's authorization endpoint. On callback, Beacon matches the authenticated email against pre-provisioned `beacon_users` records.

**Dev Mode** (development/test only): Simple email + password login without OIDC. Allows local development without configuring an identity provider. Passwords stored in `beacon_users` via bcrypt. **Disabled in production.**

### Key Design Decisions

- **Pre-provisioned users only.** OIDC login does NOT auto-create Beacon users. An admin must create the user in Beacon first. If no matching `beacon_users` record exists for the authenticated email, login is rejected with "Account not found."
- **Multiple OIDC providers.** Beacon supports a list of providers. The login page shows a button per provider. Users are matched by email across providers.
- **Email is the identity key.** A user authenticated via Google as `jane@company.com` maps to the same Beacon user as one authenticated via Azure AD as `jane@company.com`.

### Configuration

```elixir
config :beacon, :auth,
  # Production: OIDC providers
  providers: [
    google: [
      discovery_document_uri: "https://accounts.google.com/.well-known/openid-configuration",
      client_id: System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
      redirect_uri: "https://mysite.com/admin/auth/google/callback",
      response_type: "code",
      scope: "openid email profile"
    ],
    azure_ad: [
      discovery_document_uri: "https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration",
      client_id: System.get_env("AZURE_CLIENT_ID"),
      client_secret: System.get_env("AZURE_CLIENT_SECRET"),
      redirect_uri: "https://mysite.com/admin/auth/azure_ad/callback",
      response_type: "code",
      scope: "openid email profile"
    ]
  ],
  # Dev mode: enable password login (MUST be false in production)
  dev_mode: Mix.env() != :prod,
  # Session settings
  session_signing_salt: "beacon_auth",
  session_max_age: 86400 * 30  # 30 days

# openid_connect library config (referenced by Beacon)
config :openid_connect, :providers,
  google: [
    discovery_document_uri: "https://accounts.google.com/.well-known/openid-configuration",
    client_id: System.get_env("GOOGLE_CLIENT_ID"),
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
    response_type: "code",
    scope: "openid email profile"
  ]
```

### OIDC Flow

```
1. User visits /admin → not authenticated → redirect to login page
2. Login page shows buttons: "Sign in with Google", "Sign in with Azure AD"
3. User clicks provider → redirect to provider's authorization URL
4. Provider authenticates user → redirects back to /admin/auth/:provider/callback
5. Beacon exchanges code for tokens via openid_connect library
6. Beacon extracts email from ID token claims
7. Beacon looks up email in beacon_users table
8. If found → create session, redirect to admin dashboard
9. If not found → show "Account not found. Contact your administrator."
```

### Dev Mode Flow

```
1. User visits /admin → not authenticated → redirect to login page
2. Login page shows email + password form (no OIDC buttons)
3. User submits credentials
4. Beacon verifies password against beacon_users.hashed_password
5. If valid → create session, redirect to admin dashboard
```

## Authorization: Role Hierarchy

| Role | Scope | Capabilities |
|------|-------|-------------|
| **Super Admin** | Platform-wide | Manage sites, global template types, global settings, assign any role, manage all site content |
| **Site Admin** | One or more sites | Full control over assigned sites. Assign Editor/Viewer roles for their sites. |
| **Site Editor** | One or more sites | Create/edit/publish pages, manage content. Cannot change settings or template types. |
| **Site Viewer** | One or more sites | Read-only admin access. Cannot modify anything. |

## Data Model

### Migration V013

```sql
CREATE TABLE beacon_users (
  id BINARY_ID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  hashed_password TEXT,           -- Only used in dev mode
  avatar_url TEXT,                -- From OIDC profile claims
  last_login_at TIMESTAMPTZ,
  last_login_provider TEXT,       -- "google", "azure_ad", "dev"
  inserted_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);

CREATE TABLE beacon_user_sessions (
  id BINARY_ID PRIMARY KEY,
  user_id BINARY_ID NOT NULL REFERENCES beacon_users(id) ON DELETE CASCADE,
  token BYTEA NOT NULL UNIQUE,
  inserted_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX ON beacon_user_sessions (token);

CREATE TABLE beacon_user_roles (
  id BINARY_ID PRIMARY KEY,
  user_id BINARY_ID NOT NULL REFERENCES beacon_users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,              -- "super_admin", "site_admin", "site_editor", "site_viewer"
  site TEXT,                       -- NULL for super_admin, site atom string for site-scoped
  inserted_at TIMESTAMPTZ,
  UNIQUE(user_id, role, site)
);
```

### Schemas

**`Beacon.Auth.User`**
- Fields: email, name, hashed_password (optional), avatar_url, last_login_at, last_login_provider
- Changeset: required email, unique email, password hashing (dev mode only)

**`Beacon.Auth.UserSession`**
- Fields: user_id, token
- Token is a random 32-byte binary, stored as a cookie

**`Beacon.Auth.UserRole`**
- Fields: user_id, role, site
- Validates role is one of: super_admin, site_admin, site_editor, site_viewer
- super_admin roles must have site=nil
- Site-scoped roles must have a non-nil site

### Context Module: `Beacon.Auth`

```elixir
# User management
Beacon.Auth.create_user(attrs)              # Create a pre-provisioned user
Beacon.Auth.update_user(user, attrs)        # Update user profile
Beacon.Auth.delete_user(user)               # Delete user and all roles
Beacon.Auth.list_users(opts)                # List all users
Beacon.Auth.get_user_by_email(email)        # Look up by email

# Dev mode password
Beacon.Auth.set_password(user, password)    # Set password for dev mode
Beacon.Auth.verify_password(user, password) # Verify password

# Session management
Beacon.Auth.create_session(user)            # Creates session token, returns token
Beacon.Auth.get_user_by_session_token(token) # Look up user from session
Beacon.Auth.delete_session(token)           # Logout

# Role management
Beacon.Auth.assign_role(user, role, site \\ nil)
Beacon.Auth.revoke_role(user, role, site \\ nil)
Beacon.Auth.list_roles(user)
Beacon.Auth.has_role?(user, role, site \\ nil)
Beacon.Auth.authorize!(user, action, site)  # Raises if unauthorized

# OIDC
Beacon.Auth.authenticate_oidc(provider, claims)  # Match OIDC claims to user
```

## Beacon Admin Interface

### URL Structure

```
/admin/auth/login                 — Login page (OIDC buttons + dev mode form)
/admin/auth/:provider/callback    — OIDC callback
/admin/auth/logout                — Logout

/admin/beacon/                    — Beacon dashboard (super_admin only)
/admin/beacon/sites               — Manage sites
/admin/beacon/template_types      — Global template types
/admin/beacon/settings            — Global settings
/admin/beacon/users               — User management + role assignment

/admin/:site/pages                — Site-scoped (existing LiveAdmin)
/admin/:site/seo                  — Site-scoped
...
```

### Beacon Admin Pages (Super Admin Only)

**Dashboard** — Overview of all sites, user counts, recent activity

**Sites** — List configured sites with page counts, endpoints, prefixes

**Global Template Types** — Same as existing template_type_manager but with `site: nil`

**Global Settings** — AI crawler policy defaults, default meta tags, default OG image

**Users** — CRUD for pre-provisioned users:
- Create: email, name (password field only in dev mode)
- Edit: name, avatar
- Role assignment: multi-select roles with site picker for site-scoped roles
- Deactivate/delete

### Auth Integration in LiveAdmin

**New Plugs:**

`Beacon.Auth.Plug.RequireAuth` — Checks session cookie, loads user, assigns to conn. Redirects to login if not authenticated.

`Beacon.Auth.Plug.RequireRole` — Checks user's roles against the requested scope. Returns 403 if insufficient permissions.

**LiveAdmin Router Changes:**

```elixir
# In the host app's router
beacon_live_admin "/admin",
  auth: true  # Enables auth plugs in the admin pipeline
```

When `auth: true`, the admin pipeline includes:
1. `Beacon.Auth.Plug.RequireAuth` — redirect to login if no session
2. `Beacon.Auth.Plug.LoadRoles` — load user's roles into assigns
3. Route-level checks: Beacon admin pages require super_admin
4. Site pages check site-scoped roles

### OIDC Controller

**`Beacon.Auth.OIDCController`** — Handles the OAuth2/OIDC redirect flow:

```elixir
# GET /admin/auth/:provider — Redirect to OIDC provider
def authorize(conn, %{"provider" => provider})

# GET /admin/auth/:provider/callback — Handle OIDC callback
def callback(conn, %{"provider" => provider, "code" => code})
```

Uses the `openid_connect` library to:
1. Build authorization URL
2. Exchange code for tokens
3. Verify ID token
4. Extract email from claims
5. Match to beacon_users

## Implementation Phases

### Phase 1: Data Layer + Auth Context
- Migration V013 (users, sessions, roles tables)
- User, UserSession, UserRole schemas
- Beacon.Auth context with all functions
- bcrypt_elixir dependency for dev mode passwords
- openid_connect dependency

### Phase 2: OIDC Flow + Session Management
- OIDCController (authorize + callback)
- Session plug (cookie-based, token lookup)
- Login LiveView (provider buttons + dev mode form)
- Logout controller

### Phase 3: Authorization Plugs
- RequireAuth plug
- RequireRole plug
- Integration into LiveAdmin router pipeline

### Phase 4: Beacon Admin UI
- Dashboard, Sites, Global Template Types, Global Settings, Users pages
- Route mounting at /admin/beacon/ prefix
- Super admin navigation

### Phase 5: Site Admin Role Enforcement
- Existing LiveAdmin pages get role checks
- UI adaptations for different roles (hide buttons for insufficient permissions)
- Read-only mode for viewers

### Phase 6: First User Bootstrap
- Mix task: `mix beacon.create_admin --email admin@example.com`
- Creates super_admin user with password (for initial setup in dev mode)
- In production: create user via mix task, first OIDC login links to that user

## Dependencies

- `openid_connect` — OIDC discovery, token exchange, claims verification
- `bcrypt_elixir` — Password hashing for dev mode only

## Bootstrap Flow

**First deployment:**
1. Run migrations (V013 creates tables)
2. Run `mix beacon.create_admin --email admin@example.com --password secret` (dev mode) or just `--email` (OIDC mode)
3. Configure OIDC provider in config
4. First login via OIDC matches the pre-provisioned email → user gains super_admin access
5. Super admin creates more users and assigns roles via the Beacon admin UI
