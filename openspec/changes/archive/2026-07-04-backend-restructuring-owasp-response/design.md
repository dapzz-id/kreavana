## Context

The backend application is currently lacking a structured architecture, with much of the business logic and request validation living inside Controllers. Additionally, API responses do not follow a strict format. To improve maintainability and adhere to OWASP security guidelines (which suggest avoiding exposure of internal errors or unnecessary data), we will standardize the API responses and adopt a more layered architectural pattern.

## Goals / Non-Goals

**Goals:**
- Ensure all API endpoints return a standardized JSON structure: `{"status": boolean, "message": string}`.
- Use proper HTTP status codes (200, 400, 401, 403, 404, 500, etc.).
- **Performance**: Guarantee all API routes respond in under 300ms by strictly returning only necessary data.
- **Route Splitting**: If any API endpoint returns a large payload or requires heavy queries that push the response time above 300ms, split the endpoint into multiple, smaller routes to distribute the load.
- Move business logic into dedicated Service classes.
- Move database interaction into Repository classes.
- Move input validation into Laravel Form Requests.
- **Frontend Adjustments**: Ensure the frontend consumes the newly formatted and separated routes accordingly.

**Non-Goals:**
- We are not adding new functional capabilities; this is strictly a refactor of existing endpoints.

## Decisions

- **Response Format & Performance**: We will use a BaseController or a dedicated `ApiResponse` trait/helper to format responses. Every route will strictly only fetch data it explicitly requires. If an existing route fetches too many relations or large datasets, we will remove them and expose new targeted endpoints. This supports our sub-300ms response time goal.
- **Architecture**:
  - `App\Services`: Contains business logic.
  - `App\Repositories`: Contains Eloquent queries, optimized (e.g. `select()`, eager loading) to maintain low query times.
  - `App\Http\Requests`: Contains validation rules.

## Risks / Trade-offs

- [Risk] Existing clients breaking due to missing fields in the response. → Mitigation: Coordinate with frontend/mobile developers to update API consumption logic.
- [Risk] Increased number of classes due to Services and Repositories. → Mitigation: The initial overhead pays off in testability and maintainability.
