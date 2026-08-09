## ADDED Requirements

### Requirement: KYC session initialization
The system SHALL initialize a verification session when a user starts the KYC process, checking user limits using Redis cache and returning a unique transaction ID.

#### Scenario: Successful session initialization
- **WHEN** user requests to start KYC verification
- **THEN** system checks user's daily KYC attempt limit in Redis cache
- **AND** system generates a unique transaction ID
- **AND** system stores session data in Redis with appropriate TTL
- **AND** system returns transaction ID and session metadata within 300ms

#### Scenario: User exceeds daily limit
- **WHEN** user has exceeded daily KYC attempt limit
- **THEN** system returns error indicating limit reached
- **AND** system does not create a new session
- **AND** system returns response within 300ms

#### Scenario: Redis cache unavailable
- **WHEN** Redis cache is unavailable during session initialization
- **THEN** system falls back to database for limit checking
- **AND** system creates session with database fallback
- **AND** system logs cache unavailability for monitoring

### Requirement: Pre-signed S3 upload URL generation
The system SHALL generate pre-signed S3 upload URLs for KTP and Selfie images to enable direct client-to-cloud uploads.

#### Scenario: Successful upload URL generation
- **WHEN** user requests upload URLs for KTP and Selfie images
- **THEN** system validates the transaction ID exists in Redis
- **AND** system generates pre-signed S3 URLs with 15-minute TTL
- **THEN** system returns both URLs in JSON response
- **AND** system returns response within 300ms

#### Scenario: Invalid transaction ID
- **WHEN** user provides invalid or expired transaction ID
- **THEN** system returns error indicating invalid session
- **AND** system does not generate upload URLs

#### Scenario: S3 service unavailable
- **WHEN** S3 service is unavailable during URL generation
- **THEN** system returns error indicating upload service unavailable
- **AND** system logs S3 unavailability for monitoring

### Requirement: Liveness verification logging
The system SHALL receive and log client-side liveness detection metadata/tokens to verify active liveness checks were performed.

#### Scenario: Successful liveness verification logging
- **WHEN** user submits liveness detection results after on-device check
- **THEN** system validates transaction ID exists in Redis
- **AND** system logs liveness metadata (blink detected, smile detected, timestamp)
- **AND** system updates session status with liveness verification result
- **AND** system returns confirmation within 300ms

#### Scenario: Liveness check failed on client
- **WHEN** client reports liveness detection failed
- **THEN** system logs failure reason in session data
- **AND** system allows user to retry liveness check
- **AND** system does not block subsequent attempts

#### Scenario: Invalid liveness metadata
- **WHEN** liveness metadata is malformed or missing required fields
- **THEN** system returns error indicating invalid metadata
- **AND** system does not update session status

### Requirement: Face matching job initiation
The system SHALL trigger asynchronous face comparison job using AWS Rekognition with S3 URI pointers instead of raw image payloads.

#### Scenario: Successful face match job initiation
- **WHEN** user submits S3 URIs for KTP and Selfie images after upload
- **THEN** system validates both S3 URIs are accessible
- **AND** system initiates AWS Rekognition CompareFaces operation with S3 URIs
- **AND** system stores job ID in session data
- **AND** system returns job ID for status polling within 300ms

#### Scenario: S3 URIs not accessible
- **WHEN** provided S3 URIs are not accessible or invalid
- **THEN** system returns error indicating image access failure
- **AND** system does not initiate face matching job

#### Scenario: AWS Rekognition service unavailable
- **WHEN** AWS Rekognition service is unavailable
- **THEN** system returns error indicating face matching service unavailable
- **AND** system logs service unavailability for monitoring
- **AND** system allows manual retry

### Requirement: KYC status polling
The system SHALL provide a fast status polling endpoint backed by Redis cache and indexed SQL queries to return verification similarity score and KYC status.

#### Scenario: Successful status retrieval from cache
- **WHEN** user polls for KYC status using transaction ID
- **THEN** system checks Redis cache for session status
- **AND** system returns current status, similarity score, and completion timestamp
- **AND** system returns response within 300ms

#### Scenario: Status retrieval from database fallback
- **WHEN** Redis cache does not contain session status
- **THEN** system queries database using indexed (user_id, status) lookup
- **AND** system returns status from database
- **AND** system repopulates Redis cache with status data

#### Scenario: Transaction ID not found
- **WHEN** transaction ID does not exist in cache or database
- **THEN** system returns error indicating invalid transaction
- **AND** system returns response within 300ms

#### Scenario: Face matching in progress
- **WHEN** face matching job is still processing
- **THEN** system returns status as "processing"
- **AND** system includes job ID for tracking
- **AND** system returns estimated completion time if available
