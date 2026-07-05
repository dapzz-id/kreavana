<?php

return [
    'normal_route_budget_ms' => (int) env('API_NORMAL_ROUTE_BUDGET_MS', 250),
    'lightweight_response_budget_bytes' => (int) env('API_LIGHTWEIGHT_RESPONSE_BUDGET_BYTES', 300),
];
