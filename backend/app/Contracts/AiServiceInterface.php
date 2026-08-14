<?php

namespace App\Contracts;

interface AiServiceInterface
{
    /**
     * Summarize a report, contract dispute, or opportunity details.
     */
    public function summarizeReport(array $payload): array;

    /**
     * Generate smart AI recommendations for creators, opportunities, or service strategies.
     */
    public function getRecommendations(array $payload): array;

    /**
     * Assist in direct messaging (smart reply, professional tone polish, chat summary).
     */
    public function messageAssistant(array $payload): array;
}
