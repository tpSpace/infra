# Frontend Runtime Configuration Setup

## Problem

Next.js `NEXT_PUBLIC_*` environment variables are embedded at build time, not runtime. This means that setting them via Kubernetes ConfigMaps at runtime doesn't work for client-side code.

## Solution

We've implemented a runtime configuration approach that allows environment variables to be injected at container startup.

### How it works

1. **config.js** - A static JavaScript file served from `/public/config.js` that contains placeholders for runtime values
2. **docker-entrypoint.sh** - A startup script that replaces placeholders with actual environment variable values
3. **apollo-client.js** - Updated to read from `window.__RUNTIME_CONFIG__` first, then fallback to build-time config
4. **_document.js** - Includes the config.js script in the HTML head

### Files Modified

1. `lcasystem-FE/public/config.js` - Runtime configuration file
2. `lcasystem-FE/docker-entrypoint.sh` - Startup script for runtime replacement
3. `lcasystem-FE/dockerfile` - Updated to use the entrypoint script
4. `lcasystem-FE/src/utils/apollo-client.js` - Updated to use runtime config
5. `lcasystem-FE/src/pages/_document.js` - Includes config.js script

### Deployment Steps

1. Build the Docker image:

   ```bash
   docker build -t ghcr.io/tpspace/thesis-fe:latest .
   ```

2. The Kubernetes deployment (already configured) will inject the environment variable:

   ```yaml
   env:
     - name: NEXT_PUBLIC_GRAPHQL_URI
       valueFrom:
         configMapKeyRef:
           name: app-config
           key: NEXT_PUBLIC_GRAPHQL_URI
   ```

3. At container startup, the entrypoint script will replace the placeholder in `/app/public/config.js`

4. The client-side code will read the configuration from `window.__RUNTIME_CONFIG__`

### Alternative: Build-time Configuration

If you prefer to embed the environment variable at build time (less flexible but simpler), you can:

1. Build with the ARG:

   ```bash
   docker build --build-arg NEXT_PUBLIC_GRAPHQL_URI=http://34.150.46.153/api/graphql -t ghcr.io/tpspace/thesis-fe:latest .
   ```

2. Remove the runtime configuration files and revert apollo-client.js to use the original approach

### Verification

After deployment, you can verify the configuration by:

1. Opening the browser console
2. Checking `window.__RUNTIME_CONFIG__` - should show the correct GraphQL URI
3. Checking network requests - GraphQL requests should go to the configured endpoint
