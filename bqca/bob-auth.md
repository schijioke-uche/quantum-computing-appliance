<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51.0:BEGIN -->
# Version-aware Bob Shell authentication and BQCA context

`bob-auth.sh` detects the installed Bob major version. Bob 1.x retains the legacy token/config compatibility path. Bob 2.x uses the production `bob run` API-key probe already implemented in the script and does not manufacture legacy credential files. The private `.env` remains the operator-managed input.

Authentication alone does not provide the complete BQCA operating identity. Bob Shell 2.x receives BQCA project intelligence through root `AGENTS.md`, `.bob/settings.json` lifecycle hooks, `.bob/rules/00-bqca-core.md`, project custom modes, mode-specific rules, skills, quantum tools, and the offline knowledgebase. The versioned launcher exports the selected menu option/action/skill/mode for those context channels.
<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51.0:END -->

## How Bob Shell Authentication Without Browser Works

## Overview

The `bob-auth.sh` script authenticates Bob CLI by creating the configuration files that Bob expects to find when it runs.

## Authentication Flow

### 1. Bob CLI Looks for Configuration Files

When you run `bob` command, the Bob CLI automatically looks for these files:

```
~/.bob/token.json    ← Authentication token
~/.bob/config.json   ← API endpoint configuration
```

### 2. What bob-auth.sh Does

The script creates these files with your API key:

#### Creates `~/.bob/token.json`:
```json
{
  "access_token": "<some token>",
  "token_type": "Bearer",
  "expires_at": 9999999999,
  "scope": "openid email profile"
}
```

This tells Bob CLI:
- **access_token**: Your API key to use for authentication
- **token_type**: "Bearer" means it's used in HTTP Authorization header
- **expires_at**: Token expiration (set far in future so it never expires)

#### Creates `~/.bob/config.json`:
```json
{
  "apiKey": "<some token>",
  "apiEndpoint": "https://api.us-east.bob.ibm.com",
  "authEndpoint": "https://console-ibm-prod.verify.ibm.com",
  "region": "us-east"
}
```

This tells Bob CLI:
- **apiKey**: Your API key (backup reference)
- **apiEndpoint**: Where to send API requests
- **authEndpoint**: OAuth server (not used with API key auth)
- **region**: Which Bob region to use

### 3. Bob CLI Uses These Files

When you run `bob "your task"`, the Bob CLI:

1. **Reads** `~/.bob/token.json` to get your API key
2. **Reads** `~/.bob/config.json` to know which API endpoint to use
3. **Sends** HTTP request to `https://api.us-east.bob.ibm.com` with:
   ```
   Authorization: Bearer <your-api-key>
   ```
4. **Bob API** validates the API key and processes your request

## Why This Works Without Browser

**Traditional OAuth Flow (requires browser):**
```
User → Browser → Login Page → OAuth Server → Redirect → Get Token
```

**API Key Flow (no browser needed):**
```
User → bob-auth.sh → Creates token.json with API key → Bob CLI uses it directly
```

## Step-by-Step Example

### Before Running bob-auth.sh:
```bash
$ bob "hello"
# Bob CLI looks for ~/.bob/token.json
# File doesn't exist
# Bob tries to open browser for OAuth login
# ❌ Fails in headless/WSL environment
```

### After Running bob-auth.sh:
```bash
$ ./bob-auth.sh
# Creates ~/.bob/token.json with API key
# Creates ~/.bob/config.json with endpoint
# ✅ "Bob Shell Authenticated!"

$ bob "hello"
# Bob CLI looks for ~/.bob/token.json
# ✅ File exists with API key
# Bob reads API key: <some token>
# Bob sends request to: https://api.us-east.bob.ibm.com
# With header: Authorization: Bearer <some token>
# ✅ Bob API validates key and responds
```

## What Each File Does

### `.env` (Input)
```bash
BOB_API_KEY="<some token>"
BOB_ENDPOINT="https://api.us-east.bob.ibm.com"
```
- Stores your credentials
- Read by bob-auth.sh

### `tls-control.sh` (Configuration)
```bash
export NODE_TLS_REJECT_UNAUTHORIZED=0
```
- Disables SSL certificate validation
- Needed for internal IBM certificates

### `bob-auth.sh` (Main Script)
```bash
1. Load .env variables
2. Create ~/.bob/token.json with API key
3. Create ~/.bob/config.json with endpoint
4. Set file permissions (600 = owner only)
5. Display "Bob Shell Authenticated!"
```

### `~/.bob/token.json` (Output)
- Bob CLI reads this for authentication
- Contains your API key as "access_token"

### `~/.bob/config.json` (Output)
- Bob CLI reads this for API endpoint
- Tells Bob where to send requests

## Security

The API key `<some token>` is:
- Stored in `.env` file
- Copied to `~/.bob/token.json`
- Used by Bob CLI in HTTP Authorization header
- Sent to Bob API with every request

**File Permissions:**
```bash
chmod 600 ~/.bob/token.json    # Only you can read/write
chmod 600 ~/.bob/config.json   # Only you can read/write
```

## Summary

**bob-auth.sh authenticates by:**
1. Taking your API key from `.env`
2. Creating the files Bob CLI expects (`token.json`, `config.json`)
3. Bob CLI finds these files and uses the API key automatically
4. No browser needed because API key is already in the files

**It's like:**
- Giving Bob CLI your house key (API key)
- So it can unlock the door (authenticate with Bob API)
- Without needing to ask you each time (no browser popup)

---

**The authentication happens when Bob CLI reads `~/.bob/token.json` and uses the API key inside it to make authenticated requests to the Bob API.**

----



##### Author
Dr. Jeffrey Chijioke-Uche, IBM Computer scientist