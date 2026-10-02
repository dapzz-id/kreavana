<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class LocationController extends Controller
{
    /**
     * Search locations using Google Places API (if configured) with fallback to OSM/Photon.
     */
    public function search(Request $request)
    {
        $query = trim((string) $request->input('q', ''));
        $city = trim((string) $request->input('city', ''));

        if (mb_strlen($query) < 2) {
            return response()->json([
                'success' => true,
                'source' => 'empty',
                'data' => [],
            ]);
        }

        $googleKey = config('services.google.maps_api_key') ?: env('GOOGLE_MAPS_API_KEY');

        // Strategy 1: Google Places Text Search (High Accuracy)
        if (!empty($googleKey)) {
            try {
                $googleQuery = $query;
                if (!empty($city) && !str_contains(strtolower($query), strtolower($city))) {
                    $googleQuery .= ', ' . $city;
                }
                $googleQuery .= ', Indonesia';

                $response = Http::timeout(5)->get('https://maps.googleapis.com/maps/api/place/textsearch/json', [
                    'query' => $googleQuery,
                    'key' => $googleKey,
                    'language' => 'id',
                    'region' => 'id',
                ]);

                if ($response->successful()) {
                    $body = $response->json();
                    $status = $body['status'] ?? '';
                    $results = $body['results'] ?? [];

                    if ($status === 'OK' && !empty($results)) {
                        $data = [];
                        foreach (array_slice($results, 0, 8) as $item) {
                            $lat = $item['geometry']['location']['lat'] ?? null;
                            $lng = $item['geometry']['location']['lng'] ?? null;
                            if ($lat !== null && $lng !== null) {
                                $data[] = [
                                    'title' => $item['name'] ?? $query,
                                    'subtitle' => $item['formatted_address'] ?? '',
                                    'latitude' => (float) $lat,
                                    'longitude' => (float) $lng,
                                    'place_id' => $item['place_id'] ?? null,
                                    'source' => 'google_places',
                                ];
                            }
                        }

                        if (!empty($data)) {
                            return response()->json([
                                'success' => true,
                                'source' => 'google_places',
                                'data' => $data,
                            ]);
                        }
                    } elseif ($status === 'REQUEST_DENIED') {
                        Log::warning('Google Places API key invalid or request denied: ' . ($body['error_message'] ?? ''));
                    }
                }
            } catch (\Throwable $e) {
                Log::warning('Google Places API search error, falling back to OSM: ' . $e->getMessage());
            }
        }

        // Strategy 2: Photon API (Fast OpenStreetMap search)
        $osmResults = [];
        $seen = [];

        try {
            $photonQuery = $query;
            if (!empty($city) && !str_contains(strtolower($query), strtolower($city))) {
                $photonQuery .= ', ' . $city;
            }

            $photonRes = Http::timeout(4)->get('https://photon.komoot.io/api/', [
                'q' => $photonQuery,
                'limit' => 8,
            ]);

            if ($photonRes->successful()) {
                $body = $photonRes->json();
                $features = $body['features'] ?? [];
                foreach ($features as $f) {
                    $coords = $f['geometry']['coordinates'] ?? [];
                    if (count($coords) >= 2) {
                        $lon = (float) $coords[0];
                        $lat = (float) $coords[1];
                        $props = $f['properties'] ?? [];

                        $title = $props['name'] ?? $props['street'] ?? $query;
                        $parts = [];
                        if (!empty($props['street']) && $props['street'] !== $title) $parts[] = $props['street'];
                        if (!empty($props['district'])) $parts[] = $props['district'];
                        if (!empty($props['city'])) $parts[] = $props['city'];
                        if (!empty($props['state'])) $parts[] = $props['state'];
                        if (!empty($props['country'])) $parts[] = $props['country'];
                        $subtitle = implode(', ', $parts);

                        $key = round($lat, 4) . '_' . round($lon, 4);
                        if (!isset($seen[$key])) {
                            $seen[$key] = true;
                            $osmResults[] = [
                                'title' => $title,
                                'subtitle' => !empty($subtitle) ? $subtitle : $title,
                                'latitude' => $lat,
                                'longitude' => $lon,
                                'source' => 'photon',
                            ];
                        }
                    }
                }
            }
        } catch (\Throwable $e) {
            // Ignored, try Nominatim fallback
        }

        // Strategy 3: Nominatim OSM Fallback if Photon gave few results
        if (count($osmResults) < 3) {
            try {
                $nomRes = Http::timeout(4)
                    ->withHeaders(['User-Agent' => 'Kreavana-App/1.0 (contact@kreavana.com)'])
                    ->get('https://nominatim.openstreetmap.org/search', [
                        'q' => $query,
                        'format' => 'json',
                        'countrycodes' => 'id',
                        'limit' => 6,
                    ]);

                if ($nomRes->successful()) {
                    $list = $nomRes->json();
                    if (is_array($list)) {
                        foreach ($list as $item) {
                            $lat = isset($item['lat']) ? (float) $item['lat'] : null;
                            $lon = isset($item['lon']) ? (float) $item['lon'] : null;
                            $displayName = $item['display_name'] ?? '';

                            if ($lat && $lon && $displayName) {
                                $key = round($lat, 4) . '_' . round($lon, 4);
                                if (!isset($seen[$key])) {
                                    $seen[$key] = true;
                                    $comma = strpos($displayName, ',');
                                    $title = $comma !== false ? substr($displayName, 0, $comma) : $displayName;
                                    $subtitle = $comma !== false ? trim(substr($displayName, $comma + 1)) : $displayName;

                                    $osmResults[] = [
                                        'title' => $title,
                                        'subtitle' => $subtitle,
                                        'latitude' => $lat,
                                        'longitude' => $lon,
                                        'source' => 'nominatim',
                                    ];
                                }
                            }
                        }
                    }
                }
            } catch (\Throwable $e) {
                // Ignore
            }
        }

        return response()->json([
            'success' => true,
            'source' => !empty($googleKey) ? 'osm_fallback' : 'osm',
            'data' => $osmResults,
        ]);
    }

    /**
     * Reverse geocoding (coordinates -> readable address).
     */
    public function reverse(Request $request)
    {
        $lat = (float) $request->input('lat');
        $lng = (float) $request->input('lng');

        if (!$lat || !$lng) {
            return response()->json(['success' => false, 'message' => 'Koordinat lat/lng diperlukan'], 400);
        }

        $googleKey = config('services.google.maps_api_key') ?: env('GOOGLE_MAPS_API_KEY');

        // Strategy 1: Google Geocoding API
        if (!empty($googleKey)) {
            try {
                $response = Http::timeout(5)->get('https://maps.googleapis.com/maps/api/geocode/json', [
                    'latlng' => "{$lat},{$lng}",
                    'key' => $googleKey,
                    'language' => 'id',
                ]);

                if ($response->successful()) {
                    $body = $response->json();
                    if (($body['status'] ?? '') === 'OK' && !empty($body['results'][0]['formatted_address'])) {
                        return response()->json([
                            'success' => true,
                            'source' => 'google_geocoding',
                            'address' => $body['results'][0]['formatted_address'],
                        ]);
                    }
                }
            } catch (\Throwable $e) {
                Log::warning('Google Geocoding error: ' . $e->getMessage());
            }
        }

        // Strategy 2: OpenStreetMap Nominatim Reverse
        try {
            $nomRes = Http::timeout(4)
                ->withHeaders(['User-Agent' => 'Kreavana-App/1.0 (contact@kreavana.com)'])
                ->get('https://nominatim.openstreetmap.org/reverse', [
                    'lat' => $lat,
                    'lon' => $lng,
                    'format' => 'json',
                    'addressdetails' => 1,
                ]);

            if ($nomRes->successful()) {
                $data = $nomRes->json();
                $displayName = $data['display_name'] ?? null;
                if ($displayName) {
                    return response()->json([
                        'success' => true,
                        'source' => 'nominatim',
                        'address' => $displayName,
                    ]);
                }
            }
        } catch (\Throwable $e) {
            // Ignore
        }

        return response()->json([
            'success' => true,
            'source' => 'coordinates',
            'address' => "Koordinat: {$lat}, {$lng}",
        ]);
    }
}
