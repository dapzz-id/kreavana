## 1. Setup Architecture Foundations

- [x] 1.1 Create base ApiResponse helper/trait for standardized JSON output
- [x] 1.2 Create base Service class interface or abstract class
- [x] 1.3 Create base Repository interface or abstract class

## 2. Implement Repositories

- [x] 2.1 Identify and create necessary Repositories for existing models (e.g. UserRepository, PostRepository, etc. depending on what exists)
- [x] 2.2 Migrate database queries from Controllers to new Repositories

## 3. Implement Services

- [x] 3.1 Identify and create necessary Services for business logic
- [x] 3.2 Move business logic from Controllers to Services
- [x] 3.3 Ensure Services call Repositories for data access

## 4. Implement Form Requests

- [x] 4.1 Extract validation rules from Controllers into Laravel Form Request classes
- [x] 4.2 Update Form Requests to return standardized API error response on validation failure (status: false, message: validation errors)

## 5. Route Optimization and Splitting

- [x] 5.1 Identify endpoints that return heavy payloads or take >300ms to respond
- [x] 5.2 Strip unnecessary eager loaded relationships and large data fields from these endpoints
- [x] 5.3 Create new, targeted routes/endpoints specifically for fetching the separated data

## 6. Update Controllers and API Responses

- [x] 6.1 Refactor all API Controllers to use the newly created Services and Form Requests
- [x] 6.2 Ensure all successful controller responses use the ApiResponse helper (status: true, message: success)
- [x] 6.3 Ensure all error controller responses use the ApiResponse helper (status: false, message: error reason, proper HTTP code)

## 7. Frontend Adjustments

- [x] 7.1 Update frontend API calls to accommodate the new strict response format (`status`, `message`)
- [x] 7.2 Implement new frontend requests to fetch additional data from the newly split routes where needed

## 8. Testing & Verification

- [x] 8.1 Test all updated endpoints manually or via existing automated tests to verify the new response structure
- [x] 8.2 Verify that HTTP status codes match the standard (200, 400, 401, 403, 404, 422, 500)
- [x] 8.3 Profile server request times to confirm all endpoints respond in under 300ms
