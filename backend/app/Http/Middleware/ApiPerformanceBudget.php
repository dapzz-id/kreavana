<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ApiPerformanceBudget
{
    public function handle(Request $request, Closure $next): Response
    {
        $startedAt = microtime(true);

        /** @var Response $response */
        $response = $next($request);
        $elapsedMs = (int) round((microtime(true) - $startedAt) * 1000);
        $bytes = strlen((string) $response->getContent());

        $response->headers->set('X-Response-Time-Ms', (string) $elapsedMs);
        $response->headers->set('X-Response-Bytes', (string) $bytes);

        if ($elapsedMs > (int) config('api_performance.normal_route_budget_ms')) {
            $response->headers->set('X-Route-Latency-Budget', 'exceeded');
        }

        if ($bytes > (int) config('api_performance.lightweight_response_budget_bytes')) {
            $response->headers->set('X-Response-Size-Budget', 'heavy');
        }

        return $response;
    }
}
