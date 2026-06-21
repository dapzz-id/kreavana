<?php

namespace App\Services;

use App\Repositories\Contracts\PhotoRepositoryInterface;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;

/**
 * AISearchService — Text & Image-based Photo Search
 *
 * SRP: Handles only the search scoring logic.
 * DIP: Depends on PhotoRepositoryInterface, not on Eloquent directly.
 *
 * Text search uses multi-field weighted scoring (title, tags, description).
 * Image search extracts keywords from the uploaded filename and matches against photo metadata.
 * NOTE: This does NOT use any external AI/Vision API — it is keyword-based matching only.
 */
class AISearchService
{
    public function __construct(
        private readonly PhotoRepositoryInterface $photoRepository
    ) {}

    /**
     * Search photos by text using weighted relevance scoring.
     */
    public function searchByText(string $query): Collection
    {
        $query = strtolower(trim($query));
        if (empty($query)) {
            return collect();
        }

        $words   = explode(' ', $query);
        $photos  = $this->photoRepository->searchByTags($query);
        $results = collect();

        // For direct DB matches, apply full scoring on top
        $allPhotos = \App\Models\Photo::with('photographer')->get();

        foreach ($allPhotos as $photo) {
            $score = 0;
            $title = strtolower($photo->title);
            $desc  = strtolower($photo->description ?? '');
            $tags  = strtolower($photo->tags ?? '');

            if (str_contains($title, $query)) $score += 50;
            if (str_contains($tags,  $query)) $score += 40;
            if (str_contains($desc,  $query)) $score += 20;

            foreach ($words as $word) {
                if (strlen($word) < 3) continue;
                if (str_contains($title, $word)) $score += 15;
                if (str_contains($tags,  $word)) $score += 10;
                if (str_contains($desc,  $word)) $score += 5;
            }

            if ($score > 0) {
                $photo->ai_match_score = min(99, 40 + $score);
                $results->push($photo);
            }
        }

        return $results->sortByDesc('ai_match_score')->values();
    }

    /**
     * Search photos by image using Google Cloud Vision API.
     * Sends the image to Google Vision to detect labels, then matches against photo metadata.
     */
    public function searchByImage(UploadedFile $file): Collection
    {
        $detectedKeywords = [];

        try {
            // Check if credentials exist
            $credentialsPath = config('services.google.application_credentials', env('GOOGLE_APPLICATION_CREDENTIALS'));
            
            if ($credentialsPath && file_exists(base_path($credentialsPath))) {
                // Initialize the ImageAnnotatorClient
                $imageAnnotator = new \Google\Cloud\Vision\V1\ImageAnnotatorClient([
                    'credentials' => base_path($credentialsPath)
                ]);

                // Read image contents
                $imageContent = file_get_contents($file->getRealPath());

                // Perform label detection
                $response = $imageAnnotator->labelDetection($imageContent);
                $labels = $response->getLabelAnnotations();

                if ($labels) {
                    foreach ($labels as $label) {
                        // Only consider high-confidence labels
                        if ($label->getScore() >= 0.7) {
                            $detectedKeywords[] = strtolower($label->getDescription());
                        }
                    }
                }

                $imageAnnotator->close();
            } else {
                \Illuminate\Support\Facades\Log::warning('Google Vision API credentials missing. Falling back to simple keyword extraction.');
            }
        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('Google Vision API Error: ' . $e->getMessage());
        }

        // Fallback: If Vision API fails or isn't configured, extract from filename
        if (empty($detectedKeywords)) {
            $filename = strtolower($file->getClientOriginalName());
            $knownKeywords = ['nature','mountain','beach','sea','forest','animal','cat','dog','car','people','food','coffee','city','building','street','sunset','sunrise','portrait'];
            $detectedKeywords = array_filter($knownKeywords, fn($kw) => str_contains($filename, $kw));
            
            if (empty($detectedKeywords)) {
                // Absolute fallback so the search doesn't break completely
                $detectedKeywords = ['general']; 
            }
        }

        $allPhotos = \App\Models\Photo::with('photographer')->get();
        $results   = collect();

        foreach ($allPhotos as $photo) {
            $score = 0;
            $title = strtolower($photo->title);
            $desc  = strtolower($photo->description ?? '');
            $tags  = strtolower($photo->tags ?? '');

            foreach ($detectedKeywords as $keyword) {
                if (str_contains($tags,  $keyword)) $score += 40;
                if (str_contains($title, $keyword)) $score += 20;
                if (str_contains($desc,  $keyword)) $score += 10;
            }

            if ($score > 0) {
                // Determine AI match probability score (cap at 99%)
                $photo->ai_match_score = min(99, 40 + $score);
                $results->push($photo);
            }
        }

        return $results->sortByDesc('ai_match_score')->values();
    }
}
