## Why

To prevent identity fraud and spoofing while maintaining high-performance user experience, we need to separate the KYC face verification into a dedicated high-speed microservice architecture. By splitting the workflow into granular routes (max 5-6 routes) and delegating heavy AI operations asynchronously, we ensure API request-response times strictly remain under 300ms.

## What Changes

- Implement a **Microservices pattern**: Separate the Auth/Core API service from the dedicated KYC Verification Service
- Configure HTTP Connection Pooling on the Flutter frontend (`Dio`) and DB Connection Pooling on the backend to avoid handshake overhead
- Optimize backend database operations using selective indexing on `nik` / `user_id` and strict field projection (avoid `SELECT *`)
- Add `google_mlkit_face_detection` for on-device Active Liveness Detection (blink/smile detection)
- Execute **parallel/asynchronous pre-signed URL requests** so image uploads bypass the main application server and upload directly to Cloud Storage (S3)
- Implement 5 highly optimized, granular endpoints designed to execute under 300ms:
  - `POST /api/v1/kyc/session` - Initialize verification session, check user limits using Redis cache, return transaction ID
  - `POST /api/v1/kyc/upload-url` - Generate pre-signed S3 upload URLs for KTP and Selfie images
  - `POST /api/v1/kyc/liveness/verify` - Receive client-side liveness metadata/tokens to log local liveness status
  - `POST /api/v1/kyc/face-match` - Trigger comparison job asynchronously using AWS Rekognition with S3 URI pointers
  - `GET /api/v1/kyc/status/{tx_id}` - Fast status polling endpoint backed by Redis/indexed SQL query

## Capabilities

### New Capabilities
- `kyc-microservice`: Standalone verification service decoupled from core monolith application
- `direct-s3-upload`: Client-to-cloud storage upload mechanism reducing server network bottlenecks
- `fast-face-match`: Async/pointer-based biometric verification pipeline optimized for speed (<300ms latency)

### Modified Capabilities
- None (this is a new feature, not a requirement change to existing specs)

## Impact

- **Frontend**: Adds `google_mlkit_face_detection`, configures persistent `Dio` HTTP pool, handles pre-signed S3 multi-step uploads
- **Backend**: Introduces microservice boundary, S3 Pre-signed URL generation, lightweight AWS Rekognition pointer calls, and Redis caching
- **Performance**: Prevents server memory spikes during image uploads and guarantees ultra-low API latency (<300ms P95 response time, <2KB JSON responses)
