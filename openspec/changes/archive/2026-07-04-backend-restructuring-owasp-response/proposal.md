## Why

The backend currently lacks a standardized API response structure and a structured architectural pattern. This makes maintenance difficult and could expose unnecessary data in API responses. Standardizing responses to only include `status` and `message` (along with proper HTTP status codes) ensures compliance with OWASP security guidelines by preventing information leakage. Additionally, introducing a structured architecture using Services, Repositories, and Form Requests will significantly improve code maintainability, reusability, and separation of concerns.

## What Changes

- **API Response Standardization**: All API routes will be updated to return a strict JSON structure containing only `status` (boolean) and `message` (string), with appropriate HTTP status codes (e.g., 401 for Unauthorized).
- **Performance Optimization**: Ensure all API routes only return necessary data so that the Server Request Time is under 300ms. If an endpoint requires fetching heavy or additional data, it will be split into a new, separate route.
- **Architecture Restructuring**: Move business logic from Controllers to Services.
- **Database Abstraction**: Implement the Repository pattern for database interactions.
- **Request Validation**: Move validation logic from Controllers to dedicated Form Requests.
- **BREAKING**: Existing frontend or mobile clients relying on previous API response structures (e.g., nested data objects, specific error structures) will need to be updated to handle the new `status` and `message` format, as well as adapt to the new separated routes for additional data.

## Capabilities

### New Capabilities
- `api-response-standardization`: Standardizing all API responses to follow OWASP security guidelines.
- `api-performance-optimization`: Optimizing routes to ensure server response time is < 300ms, splitting heavy data loads into separate routes.
- `backend-restructuring`: Restructuring the backend to use Services, Repositories, and Form Requests.

### Modified Capabilities

- 

## Impact

- **Affected Code**: All existing Controllers, Routes, and potentially Models.
- **APIs**: All API endpoints will have their response payloads modified.
- **Clients**: Any frontend (web/mobile) consuming these APIs will be impacted and requires coordination.
