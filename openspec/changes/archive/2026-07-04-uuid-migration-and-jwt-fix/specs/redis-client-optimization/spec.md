## ADDED Requirements

### Requirement: phpredis Client Configuration
The system SHALL use the `phpredis` extension for all Redis connections (caching, queues, sessions) instead of the `predis` library to optimize performance and reduce memory overhead.

#### Scenario: Application connects to Redis
- **WHEN** the Laravel application establishes a connection to the configured Redis server
- **THEN** it uses the native `phpredis` extension as defined by the `REDIS_CLIENT` environment configuration.
