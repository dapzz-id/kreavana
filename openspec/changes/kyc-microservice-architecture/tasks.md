## 1. Backend Setup

- [x] 1.1 Create new Laravel service structure for KYC microservice
- [x] 1.2 Configure Laravel service to run on separate port/domain
- [x] 1.3 Add AWS SDK for PHP dependency to composer.json
- [x] 1.4 Add Redis/phpredis dependency for caching
- [x] 1.5 Configure environment variables for AWS credentials and S3 bucket
- [x] 1.6 Configure environment variables for Redis connection
- [x] 1.7 Configure CORS settings for Flutter frontend access

## 2. Database & Redis Setup

- [x] 2.1 Create kyc_verifications table migration with user_id, status, similarity_score, s3_ktp_uri, s3_selfie_uri fields
- [x] 2.2 Add composite database index on (user_id, status)
- [x] 2.3 Add database index on transaction_id column
- [ ] 2.4 Run database migrations
- [x] 2.5 Configure Redis connection in Laravel
- [x] 2.6 Set up Redis key structure for session caching (kyc:session:{tx_id})
- [x] 2.7 Set up Redis key structure for user limit tracking (kyc:limits:{user_id})

## 3. S3 Configuration

- [x] 3.1 Create S3 bucket for KYC image storage
- [x] 3.2 Configure S3 bucket CORS policy for direct Flutter uploads
- [x] 3.3 Set up S3 lifecycle policy for image retention
- [x] 3.4 Configure IAM role/policy for Laravel service to access S3
- [x] 3.5 Test S3 pre-signed URL generation functionality

## 4. Backend API Implementation - Session Endpoint

- [x] 4.1 Create POST /api/v1/kyc/session route
- [x] 4.2 Implement session initialization logic with Redis cache
- [x] 4.3 Add daily KYC attempt limit checking using Redis
- [x] 4.4 Generate unique transaction ID for each session
- [x] 4.5 Store session data in Redis with appropriate TTL
- [x] 4.6 Add database fallback when Redis is unavailable
- [x] 4.7 Add error handling for limit exceeded scenarios
- [x] 4.8 Add logging for monitoring and debugging

## 5. Backend API Implementation - Upload URL Endpoint

- [x] 5.1 Create POST /api/v1/kyc/upload-url route
- [x] 5.2 Implement transaction ID validation against Redis
- [x] 5.3 Generate pre-signed S3 URLs for KTP upload (15-minute TTL)
- [x] 5.4 Generate pre-signed S3 URLs for Selfie upload (15-minute TTL)
- [x] 5.5 Return both URLs in JSON response
- [x] 5.6 Add error handling for invalid transaction IDs
- [x] 5.7 Add error handling for S3 service unavailability
- [x] 5.8 Add logging for URL generation events

## 6. Backend API Implementation - Liveness Verification Endpoint

- [x] 6.1 Create POST /api/v1/kyc/liveness/verify route
- [x] 6.2 Implement transaction ID validation
- [x] 6.3 Parse and validate liveness metadata from request
- [x] 6.4 Log liveness detection results (blink, smile, timestamp)
- [x] 6.5 Update session status with liveness verification result
- [x] 6.7 Add error handling for malformed metadata
- [x] 6.8 Add logging for liveness verification events

## 7. Backend API Implementation - Face Match Endpoint

- [x] 7.1 Create POST /api/v1/kyc/face-match route
- [x] 7.2 Implement S3 URI validation and accessibility check
- [x] 7.3 Integrate AWS Rekognition CompareFaces operation
- [x] 7.4 Implement async job initiation with job queue
- [x] 7.5 Store job ID in session data
- [x] 7.6 Return job ID immediately without waiting for completion
- [x] 7.7 Add error handling for invalid S3 URIs
- [x] 7.8 Add error handling for AWS Rekognition unavailability
- [x] 7.9 Implement exponential backoff for rate limit handling
- [x] 7.10 Add logging for face match job initiation

## 8. Backend API Implementation - Status Polling Endpoint

- [x] 8.1 Create GET /api/v1/kyc/status/{tx_id} route
- [x] 8.2 Implement Redis cache lookup for session status
- [x] 8.3 Add database fallback when cache miss occurs
- [x] 8.4 Use indexed (user_id, status) query for database lookup
- [x] 8.5 Return status, similarity score, and completion timestamp
- [x] 8.6 Implement cache repopulation after database lookup
- [x] 8.7 Add error handling for invalid transaction IDs
- [x] 8.8 Add strict field projection to minimize response size
- [x] 8.9 Add logging for status polling events

## 9. AWS Rekognition Integration

- [x] 9.1 Configure AWS Rekognition client in Laravel
- [x] 9.2 Implement CompareFaces operation with S3 URI pointers
- [x] 9.3 Set up job queue for async face matching processing
- [x] 9.4 Implement job worker to process face match queue
- [x] 9.5 Add similarity score threshold validation logic
- [x] 9.6 Update kyc_verifications table with face match results
- [x] 9.7 Update Redis cache with completion status
- [x] 9.8 Add error handling for image quality issues
- [x] 9.9 Add monitoring for Rekognition API usage and costs

## 10. Frontend Setup - Flutter Dependencies

- [x] 10.1 Add google_mlkit_face_detection dependency to pubspec.yaml
- [x] 10.2 Add dio dependency to pubspec.yaml
- [x] 10.3 Add amazon_cognito_identity_dart dependency for S3 (if needed)
- [x] 10.4 Run flutter pub get to install dependencies
- [x] 10.5 Configure environment variables for API endpoints

## 11. Frontend - Dio Configuration

- [x] 11.1 Create dedicated Dio instance for KYC microservice
- [x] 11.2 Configure connection pooling settings (max connections, keep-alive)
- [x] 11.3 Set connectTimeout to 3000ms
- [x] 11.4 Set receiveTimeout to 3000ms
- [x] 11.5 Add interceptors for request/response logging
- [x] 11.6 Add retry logic for failed requests
- [x] 11.7 Test connection pooling performance

## 12. Frontend - Google ML Kit Integration

- [x] 12.1 Create liveness detection service class
- [x] 12.2 Implement face detection using Google ML Kit
- [x] 12.3 Implement blink detection logic
- [x] 12.4 Implement smile detection logic
- [x] 12.5 Add random challenge generation for anti-spoofing
- [x] 12.6 Create liveness detection UI with camera preview
- [x] 12.7 Add progress indicators during liveness check
- [x] 12.8 Add error handling for camera permission issues
- [x] 12.9 Test liveness detection accuracy

## 13. Frontend - S3 Upload Implementation

- [x] 13.1 Create S3 upload service class
- [x] 13.2 Implement pre-signed URL retrieval from microservice
- [x] 13.3 Implement direct S3 upload using pre-signed URLs
- [x] 13.4 Implement parallel upload for KTP and Selfie images
- [x] 13.5 Add upload progress tracking UI
- [x] 13.6 Add error handling for upload failures
- [x] 13.7 Implement URL expiration refresh logic
- [x] 13.8 Add retry mechanism for failed uploads
- [x] 13.9 Store S3 URIs after successful upload

## 14. Frontend - KYC Flow Integration

- [x] 14.1 Update KYC verification screen to use new microservice endpoints
- [x] 14.2 Implement session initialization on KYC start
- [x] 14.3 Integrate liveness detection into KYC flow
- [x] 14.4 Replace server upload with direct S3 upload
- [x] 14.5 Implement face match job initiation after uploads
- [x] 14.6 Implement status polling for face match results
- [x] 14.7 Display similarity score and verification status
- [x] 14.8 Add error handling for each step in the flow
- [x] 14.9 Add loading indicators for async operations
- [x] 14.10 Update UI to handle all error scenarios

## 15. Performance Optimization

- [ ] 15.1 Verify all API endpoints return within 300ms (P95)
- [ ] 15.2 Optimize database queries with EXPLAIN analysis
- [ ] 15.3 Verify Redis cache hit rates are acceptable
- [ ] 15.4 Test connection pooling performance under load
- [ ] 15.5 Verify JSON response sizes are under 2KB
- [ ] 15.6 Add performance monitoring and alerting
- [ ] 15.7 Optimize image compression before upload

## 16. Testing

- [ ] 16.1 Test session initialization with valid user
- [ ] 16.2 Test session initialization with exceeded limit
- [ ] 16.3 Test pre-signed URL generation
- [ ] 16.4 Test direct S3 upload with valid images
- [ ] 16.5 Test S3 upload with expired URLs
- [ ] 16.6 Test liveness detection with real user
- [ ] 16.7 Test liveness detection with spoofing attempts
- [ ] 16.8 Test face match initiation with valid S3 URIs
- [ ] 16.9 Test face match with invalid S3 URIs
- [ ] 16.10 Test status polling with cache hit
- [ ] 16.11 Test status polling with cache miss
- [ ] 16.12 Test complete KYC flow end-to-end
- [ ] 16.13 Test error handling for each failure scenario
- [ ] 16.14 Load test API endpoints to verify 300ms target
- [ ] 16.15 Test Redis fallback to database

## 17. Deployment

- [ ] 17.1 Deploy KYC microservice to staging environment
- [ ] 17.2 Configure staging environment variables
- [ ] 17.3 Test staging deployment with real data
- [ ] 17.4 Set up monitoring and logging for microservice
- [ ] 17.5 Configure AWS Rekognition cost alerts
- [ ] 17.6 Implement feature flag for gradual rollout
- [ ] 17.7 Deploy to production with feature flag disabled
- [ ] 17.8 Enable feature flag for small user segment
- [ ] .17.9 Monitor performance metrics and error rates
- [ ] 17.10 Gradually increase rollout percentage
- [ ] 17.11 Document rollback procedure
