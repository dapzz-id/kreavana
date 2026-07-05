## Why

The database currently uses a mix of UUIDs (for `users`, `user_follows`) and auto-incrementing integer IDs (for `chats`, `messages`, `notifications`, `auth_logs`, etc.). Standardizing on UUIDs for all primary keys improves security (unpredictable IDs), enables distributed ID generation, and simplifies frontend-backend data handling. 
Additionally, there is a configuration mismatch in JWT authentication where the `.env` file specifies the asymmetric `RS256` algorithm but lacks valid RSA keys, causing login failures. This needs to be resolved by reverting to the symmetric `HS256` algorithm which aligns with the generated `JWT_SECRET`.
Finally, the application currently uses `predis` for Redis connections. Switching to the native PHP extension `phpredis` will improve performance and resource efficiency for caching and queue management.

## What Changes

- **BREAKING**: Migrate all auto-incrementing integer primary keys (`id`) to `uuid` across all relevant database tables (`chats`, `chat_participants`, `messages`, `notifications`, `sub_role_categories`, `user_sub_roles`, `opportunities`, `creator_applications`, `dashboard_stats`, `reports`, `wallet_transactions`, `auth_logs`, `user_sessions`).
- Update all foreign key constraints that reference these tables to also use UUIDs.
- Update Laravel Eloquent Models to use the `HasUuids` trait and set `$keyType = 'string'` and `$incrementing = false` where applicable.
- Fix JWT Configuration in `.env` by changing `JWT_ALGO` to `HS256` (or removing it to use the default) and removing `JWT_PRIVATE_KEY` / `JWT_PUBLIC_KEY` references.
- Change `REDIS_CLIENT` in `.env` from `predis` to `phpredis` to optimize Redis connections.

## Capabilities

### New Capabilities
- `uuid-standardization`: Standardize all database primary keys to use UUIDs instead of auto-incrementing integers.
- `redis-client-optimization`: Change the Redis client from `predis` to `phpredis` for better performance.

### Modified Capabilities
- `unified-auth`: Fix the JWT algorithm mismatch that currently breaks the login process.

## Impact

- **Database**: All tables with integer IDs will be modified. All foreign keys referencing these tables will be updated. This requires dropping and recreating tables or running complex migration statements. Since the project is in development, refreshing migrations (`php artisan migrate:fresh`) might be the simplest approach.
- **Models**: All Eloquent models previously relying on auto-incrementing IDs will need updates to use UUIDs.
- **Authentication**: JWT login will start working again after fixing the environment variables.
- **Infrastructure**: Redis caching and queuing will use the faster `phpredis` extension, requiring the PHP extension to be installed on the server (which is typical for most environments).
