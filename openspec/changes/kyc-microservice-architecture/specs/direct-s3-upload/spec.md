## ADDED Requirements

### Requirement: Direct S3 upload initiation
The system SHALL enable Flutter client to upload images directly to S3 using pre-signed URLs, bypassing the application server.

#### Scenario: Successful direct S3 upload
- **WHEN** Flutter client receives pre-signed S3 upload URLs
- **THEN** client uploads KTP image directly to S3 using provided URL
- **AND** client uploads Selfie image directly to S3 using provided URL
- **AND** uploads happen in parallel to reduce total upload time
- **AND** application server is not involved in image transfer

#### Scenario: Upload URL expiration handling
- **WHEN** pre-signed S3 URL expires before upload completes
- **THEN** client requests new upload URLs from microservice
- **AND** system generates fresh pre-signed URLs
- **AND** client retries upload with new URLs

#### Scenario: S3 upload failure
- **WHEN** direct S3 upload fails due to network error or S3 issue
- **THEN** client displays appropriate error message to user
- **AND** client allows user to retry upload
- **AND** client does not fallback to server upload

### Requirement: Parallel upload execution
The system SHALL support parallel execution of KTP and Selfie image uploads to minimize total upload time.

#### Scenario: Parallel upload execution
- **WHEN** user has both KTP and Selfie images ready
- **THEN** client initiates both uploads simultaneously
- **AND** uploads progress independently
- **AND** client displays individual progress for each upload

#### Scenario: Sequential upload fallback
- **WHEN** parallel upload is not supported or fails
- **THEN** client falls back to sequential upload
- **AND** client uploads KTP first, then Selfie
- **AND** total upload time increases but functionality remains

### Requirement: Upload progress tracking
The system SHALL provide real-time upload progress feedback to users during direct S3 uploads.

#### Scenario: Upload progress display
- **WHEN** direct S3 upload is in progress
- **THEN** client displays progress indicator for each image
- **AND** progress indicator shows percentage complete
- **AND** progress indicator updates in real-time

#### Scenario: Upload completion notification
- **WHEN** both KTP and Selfie uploads complete successfully
- **THEN** client displays success message
- **AND** client proceeds to next step in KYC flow
- **AND** client stores S3 URIs for subsequent API calls

### Requirement: Upload error handling
The system SHALL handle S3 upload errors gracefully without affecting application server stability.

#### Scenario: Network interruption during upload
- **WHEN** network connection is lost during S3 upload
- **THEN** client detects upload failure
- **AND** client allows user to retry upload
- **AND** client does not crash or hang

#### Scenario: S3 service unavailable
- **WHEN** S3 service is unavailable during upload
- **THEN** client displays error message indicating S3 issue
- **AND** client allows user to retry later
- **AND** client logs error for monitoring
