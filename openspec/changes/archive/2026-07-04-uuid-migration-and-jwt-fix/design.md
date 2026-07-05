## Context

The backend is currently in a state where some tables (like `users`) use UUIDs, while the majority still rely on auto-incrementing integers. This causes inconsistency when working with Eloquent relationships and API payloads. The user wants to fully standardize on UUIDs across all tables.
Simultaneously, the JWT authentication is broken. A JWT secret exists, but the algorithm configured in `.env` is `RS256` which requires RSA keys (`jwt-private.pem` and `jwt-public.pem`). Because these files don't exist or are invalid, `tymon/jwt-auth` throws an unsupported decoder exception.

## Goals / Non-Goals

**Goals:**
- Migrate all remaining auto-incrementing primary keys to UUIDs.
- Update all associated foreign key relationships in migrations to UUIDs.
- Update Eloquent models to correctly configure UUID primary keys.
- Fix JWT configuration to restore login functionality.
- Change Redis client to `phpredis` for better performance.

**Non-Goals:**
- Data migration for existing production data (assuming this is early development and `migrate:fresh` is acceptable).

## Decisions

**Database Standardization to UUIDs:**
- We will modify the existing migration files rather than creating new ones. This is the cleanest approach for a project in development.
- Tables to update: `chats`, `chat_participants`, `messages`, `notifications`, `sub_role_categories`, `user_sub_roles`, `opportunities`, `creator_applications`, `dashboard_stats`, `reports`, `wallet_transactions`, `auth_logs`, `user_sessions`.
- For foreign keys (e.g., `$table->foreignId('chat_id')`), we will change them to `$table->uuid('chat_id')` or use Laravel's foreignUuid method (`$table->foreignUuid('chat_id')`).

**Model Configuration:**
- For every model that gets a UUID primary key, we will include the `Illuminate\Database\Eloquent\Concerns\HasUuids` trait.
- Alternatively, we'll manually set `public $incrementing = false;` and `protected $keyType = 'string';` alongside a boot method to generate UUIDs if the trait is not available, but Laravel 9+ provides `HasUuids` natively.

**JWT Configuration Fix:**
- In the `.env` file, we will set `JWT_ALGO=HS256`.
- We will remove `JWT_PRIVATE_KEY` and `JWT_PUBLIC_KEY` variables to avoid confusion.
- The `tymon/jwt-auth` package will naturally fall back to using the `JWT_SECRET` string with the `HS256` algorithm.

**Redis Client Optimization:**
- We will update the `REDIS_CLIENT` environment variable in `.env` from `predis` to `phpredis`.
- `phpredis` is a compiled C extension for PHP which generally offers significantly better performance for Redis operations compared to the PHP-based `predis` library.

## Risks / Trade-offs

- **Risk:** Existing data will be lost during `migrate:fresh`.
  - **Mitigation:** Communicate this to the developer. Since the system is not yet fully live, this is an acceptable trade-off for a cleaner migration history.
- **Risk:** Missed relationships where a foreign key is still defined as an integer.
  - **Mitigation:** We will thoroughly search the migration files and model relationships to ensure full coverage.
