## Context

The current KYC verification process is integrated into the main monolithic application, causing performance bottlenecks during image uploads and face matching operations. The system uses synchronous processing which blocks API responses, often exceeding 300ms latency targets. The application uses Flutter for the frontend and Laravel for the backend, with a MySQL database. Current implementation uploads images directly to the application server before processing, causing memory spikes and network congestion.

## Goals / Non-Goals

**Goals:**
- Separate KYC verification into a dedicated microservice with <300ms API response times
- Implement direct S3 uploads to bypass application server for image transfers
- Add on-device liveness detection using Google ML Kit Face Detection
- Implement asynchronous face matching using AWS Rekognition with S3 URI pointers
- Configure HTTP connection pooling on frontend and DB connection pooling on backend
- Optimize database queries with selective indexing and field projection
- Implement Redis caching for session management and status lookups

**Non-Goals:**
- Complete rewrite of existing authentication system (only KYC verification is affected)
- Offline-only processing (system will support both online and offline modes)
- Real-time video streaming for liveness detection (uses static image analysis)
- Multi-cloud storage support (S3-only implementation)
- Complex retry logic for failed face matching (simple error handling with manual retry)

## Decisions

**Microservices Architecture**
- **Choice**: Separate KYC verification into dedicated microservice with 5 granular endpoints
- **Rationale**: Decouples heavy AI operations from core API, allows independent scaling, simplifies performance optimization, enables <300ms response targets
- **Alternatives considered**:
  - Keep in monolith with optimization (would still have resource contention)
  - Serverless functions (cold start latency concerns, complexity in state management)

**Direct S3 Upload**
- **Choice**: Generate pre-signed S3 URLs for client-to-cloud uploads
- **Rationale**: Eliminates application server as bottleneck, reduces memory usage, leverages S3 bandwidth, enables parallel uploads
- **Alternatives considered**:
  - Upload through application server (causes memory spikes, slower)
  - CDN-based uploads (adds complexity, cost overhead)

**On-Device Liveness Detection**
- **Choice**: Use Google ML Kit Face Detection for client-side blink/smile detection
- **Rationale**: Privacy (no raw video sent to server), reduces server load, instant feedback, no additional API costs
- **Alternatives considered**:
  - Server-side liveness detection (higher latency, privacy concerns, cost)
  - Third-party liveness APIs (subscription costs, dependency on external service)

**Asynchronous Face Matching**
- **Choice**: Trigger AWS Rekognition comparison job with S3 URI pointers, poll for results
- **Rationale**: Keeps API response fast (<300ms), avoids blocking on heavy AI operations, leverages AWS managed service
- **Alternatives considered**:
  - Synchronous face matching (would exceed 300ms target)
  - Local face matching (requires ML model deployment, maintenance overhead)

**HTTP Connection Pooling**
- **Choice**: Configure persistent Dio instances with connection pooling (connectTimeout: 3000ms, receiveTimeout: 3000ms)
- **Rationale**: Reduces TCP handshake overhead, improves throughput, enables connection reuse
- **Alternatives considered**:
  - Default HTTP client (no pooling, slower)
  - gRPC (overkill for REST API, adds complexity)

**Database Optimization**
- **Choice**: Add composite indexes on (user_id, status), use Redis for session caching, strict field projection
- **Rationale**: Fast lookups for status polling, reduces DB load, minimizes query execution time
- **Alternatives considered**:
  - Full table scans (too slow)
  - Materialized views (adds complexity, not needed for simple lookups)

**5-Endpoint Granularity**
- **Choice**: Split into exactly 5 endpoints (session, upload-url, liveness/verify, face-match, status)
- **Rationale**: Each endpoint has single responsibility, enables parallel execution, easy to monitor and optimize
- **Alternatives considered**:
  - Single endpoint (too complex, hard to optimize)
  - More granular endpoints (over-engineering, adds network overhead)

## Risks / Trade-offs

**[Risk] S3 pre-signed URL expiration** → Mitigation: Set appropriate TTL (15 minutes), handle expired URLs gracefully with refresh logic

**[Risk] AWS Rekognition API rate limits** → Mitigation: Implement exponential backoff, use queue for job processing, monitor usage

**[Risk] Client-side liveness detection spoofing** → Mitigation: Combine with server-side face matching, add random challenge requests, monitor patterns

**[Risk] Microservice communication latency** → Mitigation: Deploy in same AWS region, use internal networking, monitor inter-service latency

**[Risk] Redis cache invalidation** → Mitigation: Use appropriate TTL, implement cache warming, have DB fallback

**[Trade-off] Increased system complexity** → Mitigation: Clear service boundaries, comprehensive monitoring, good documentation

**[Trade-off] Additional AWS costs** → Mitigation: Monitor usage, implement cost alerts, optimize Rekognition calls

**[Trade-off] Client-side processing increases app size** → Mitigation: Google ML Kit is optimized (~5-10MB), acceptable trade-off for performance

## Migration Plan

1. Create new Laravel service for KYC microservice with 5 endpoints
2. Add database indexes on kyc_verifications table (user_id, status)
3. Configure Redis for session caching and status storage
4. Set up S3 bucket with CORS configuration for direct uploads
5. Implement pre-signed URL generation endpoint
6. Add Google ML Kit Face Detection to Flutter app
7. Implement liveness detection logic in Flutter (blink/smile detection)
8. Modify Flutter Dio configuration for connection pooling
9. Implement direct S3 upload flow in Flutter
10. Integrate AWS Rekognition for face matching with async job queue
11. Implement status polling endpoint with Redis cache
12. Update Flutter KYC flow to use new microservice endpoints
13. Deploy microservice to staging environment
14. Performance testing to verify <300ms targets
15. Gradual rollout to production with feature flag
16. Monitor performance metrics and error rates

**Rollback Strategy**: Feature flag to revert to old monolithic KYC flow, maintain old endpoints temporarily, database schema compatible with both implementations

## Open Questions

- What is the expected daily volume of KYC verifications? (affects Rekognition cost planning)
- Should we implement rate limiting per user for KYC attempts? (security consideration)
- What is the acceptable false positive rate for face matching? (affects threshold tuning)
- Should we store raw S3 URIs or obfuscated references in database? (security consideration)
