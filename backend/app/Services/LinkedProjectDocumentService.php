<?php

namespace App\Services;

use App\Models\InstitutionResource;
use App\Models\JobContract;
use App\Models\Opportunity;
use App\Models\OpportunityApplication;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Aggregates live, database-backed documents, contracts, and MoUs linked from
 * Proyek Saya (JobContract, Opportunity, OpportunityApplication) and cleans up
 * orphaned partner MoU documents whose underlying partner row no longer exists.
 */
class LinkedProjectDocumentService
{
    /**
     * Exclude synced partner MoU documents whose parent partner record has been deleted.
     *
     * @param  Collection<int, InstitutionResource>  $resources
     * @return Collection<int, InstitutionResource>
     */
    public function filterOrphanedPartnerDocuments(Collection $resources): Collection
    {
        if ($resources->isEmpty()) {
            return $resources;
        }

        $partnerIds = $resources
            ->filter(fn (InstitutionResource $item) => $item->resource_type === 'documents')
            ->map(function (InstitutionResource $item) {
                $meta = is_array($item->metadata) ? $item->metadata : [];

                return trim((string) ($meta['partner_resource_id'] ?? ''));
            })
            ->filter(fn (string $id) => $id !== '')
            ->unique()
            ->values();

        if ($partnerIds->isEmpty()) {
            return $resources;
        }

        $existingPartnerIds = InstitutionResource::query()
            ->where('resource_type', 'partners')
            ->whereIn('id', $partnerIds->all())
            ->pluck('id')
            ->map(fn ($id) => (string) $id)
            ->flip();

        return $resources
            ->filter(function (InstitutionResource $item) use ($existingPartnerIds) {
                if ($item->resource_type !== 'documents') {
                    return true;
                }

                $meta = is_array($item->metadata) ? $item->metadata : [];
                $partnerId = trim((string) ($meta['partner_resource_id'] ?? ''));
                if ($partnerId === '') {
                    return true;
                }

                return $existingPartnerIds->has($partnerId);
            })
            ->values();
    }

    /**
     * Collect all live documents, contracts, wet-signature MoUs, acceptance letters,
     * and uploaded project attachments from Proyek Saya for the given owner account.
     *
     * @return Collection<int, array<string, mixed>>
     */
    public function collectForUser(string $ownerId, ?User $ownerUser = null): Collection
    {
        if ($ownerId === '') {
            return collect();
        }

        $items = collect();
        $seenContractPairs = [];
        $seenUrls = [];

        $contracts = JobContract::query()
            ->where(function ($q) use ($ownerId) {
                $q->where('client_id', $ownerId)
                    ->orWhere('creator_id', $ownerId);
            })
            ->with([
                'client:id,name,username,avatar_url,sub_role',
                'creator:id,name,username,avatar_url,sub_role',
                'opportunity:id,title,deadline,event_start_date,event_end_date,event_date',
            ])
            ->latest()
            ->get();

        foreach ($contracts as $contract) {
            if (!empty($contract->opportunity_id) && !empty($contract->creator_id)) {
                $seenContractPairs[$contract->opportunity_id . ':' . $contract->creator_id] = true;
            }

            $items->push($this->mapJobContractToDocument($contract));

            $deliverables = is_array($contract->deliverables) ? $contract->deliverables : [];
            $scopeKey = !empty($contract->opportunity_id)
                ? 'opp:' . $contract->opportunity_id
                : 'ctr:' . $contract->id;

            foreach ($deliverables as $idx => $entry) {
                if (!is_array($entry)) {
                    continue;
                }
                $mapped = $this->mapAttachmentEntry(
                    id: 'project-contract-file-' . $contract->id . '-' . $idx,
                    userId: (string) $contract->client_id,
                    projectTitle: (string) $contract->title,
                    opportunityId: $contract->opportunity_id ? (string) $contract->opportunity_id : null,
                    contractId: (string) $contract->id,
                    sourceType: 'project_deliverable',
                    category: 'Dokumen Hasil Kerja Proyek',
                    authorName: $contract->creator?->name ?? $contract->client?->name ?? ($ownerUser?->name ?? 'Kreavana'),
                    entry: $entry,
                    scopeKey: $scopeKey,
                    seenUrls: $seenUrls,
                );
                if ($mapped !== null) {
                    $items->push($mapped);
                }
            }
        }

        $opportunities = Opportunity::query()
            ->where(function ($q) use ($ownerId) {
                $q->where('posted_by', $ownerId)
                    ->orWhereHas('applications', function ($appQ) use ($ownerId) {
                        $appQ->where('creator_id', $ownerId);
                    });
            })
            ->with([
                'user:id,name,username,avatar_url,sub_role',
                'applications' => function ($q) {
                    $q->where('status', '!=', 'rejected')
                        ->with('creator:id,name,username,avatar_url,sub_role')
                        ->latest();
                },
            ])
            ->orderByDesc('created_at')
            ->get();

        foreach ($opportunities as $opp) {
            $isOppOwner = (string) $opp->posted_by === $ownerId;
            $visibleApps = $isOppOwner
                ? $opp->applications
                : $opp->applications->where('creator_id', $ownerId)->values();

            if (!$isOppOwner && $visibleApps->isEmpty()) {
                continue;
            }

            $scopeKey = 'opp:' . $opp->id;
            $hasApprovedForViewer = $isOppOwner || $visibleApps->contains(fn ($a) => $a->status === 'approved');

            if (!empty($opp->wet_signature_document_url)) {
                $wetUrl = trim((string) $opp->wet_signature_document_url);
                $seenUrls[$scopeKey . ':' . strtolower($wetUrl)] = true;
                $items->push($this->mapOpportunityWetMou($opp));
            }

            if (!empty($opp->official_acceptance_letter_url) && $hasApprovedForViewer) {
                $letterUrl = trim((string) $opp->official_acceptance_letter_url);
                $seenUrls[$scopeKey . ':' . strtolower($letterUrl)] = true;
                $items->push($this->mapOpportunityAcceptanceLetter($opp));
            }

            foreach ($visibleApps as $app) {
                $pairKey = $opp->id . ':' . $app->creator_id;
                $hasContractSignal = !empty($app->contract_number)
                    || !empty($app->client_signature)
                    || !empty($app->creator_signature)
                    || ($app->status === 'approved' && strtolower((string) $opp->sub_role_slug) !== 'magang');

                if (!isset($seenContractPairs[$pairKey]) && $hasContractSignal) {
                    $seenContractPairs[$pairKey] = true;
                    $items->push($this->mapApplicationToContractDocument($opp, $app));
                }

                $submittedDocs = is_array($app->submitted_documents) ? $app->submitted_documents : [];
                foreach ($submittedDocs as $idx => $entry) {
                    if (!is_array($entry)) {
                        continue;
                    }
                    $mapped = $this->mapAttachmentEntry(
                        id: 'project-app-doc-' . $app->id . '-' . $idx,
                        userId: (string) $opp->posted_by,
                        projectTitle: (string) $opp->title,
                        opportunityId: (string) $opp->id,
                        contractId: null,
                        sourceType: 'project_submitted_document',
                        category: 'Dokumen Lampiran Proyek',
                        authorName: $app->creator?->name ?? $opp->user?->name ?? 'Kreavana',
                        entry: $entry,
                        scopeKey: $scopeKey,
                        seenUrls: $seenUrls,
                    );
                    if ($mapped !== null) {
                        $items->push($mapped);
                    }
                }

                $submittedDeliverables = is_array($app->submitted_deliverables) ? $app->submitted_deliverables : [];
                foreach ($submittedDeliverables as $idx => $entry) {
                    if (!is_array($entry)) {
                        continue;
                    }
                    $mapped = $this->mapAttachmentEntry(
                        id: 'project-app-deliv-' . $app->id . '-' . $idx,
                        userId: (string) $opp->posted_by,
                        projectTitle: (string) $opp->title,
                        opportunityId: (string) $opp->id,
                        contractId: null,
                        sourceType: 'project_deliverable',
                        category: 'Dokumen Hasil Kerja Proyek',
                        authorName: $app->creator?->name ?? $opp->user?->name ?? 'Kreavana',
                        entry: $entry,
                        scopeKey: $scopeKey,
                        seenUrls: $seenUrls,
                    );
                    if ($mapped !== null) {
                        $items->push($mapped);
                    }
                }
            }
        }

        return $items;
    }

    /**
     * @return array<string, mixed>
     */
    private function mapJobContractToDocument(JobContract $contract): array
    {
        $contractNumber = trim((string) ($contract->contract_number ?? ''));
        if ($contractNumber === '') {
            $contractNumber = 'CTR-' . strtoupper(substr(str_replace('-', '', (string) $contract->id), 0, 8));
        }

        $contractStatus = $contract->contract_status instanceof \BackedEnum
            ? $contract->contract_status->value
            : (string) $contract->contract_status;

        $clientName = $contract->client?->name ?? 'Klien Proyek';
        $creatorName = $contract->creator?->name ?? 'Kreator / Mitra';
        $clientSigned = !empty($contract->client_signature) || !empty($contract->client_signed_at) || (bool) $contract->client_approved;
        $creatorSigned = !empty($contract->creator_signature) || !empty($contract->creator_signed_at) || (bool) $contract->creator_approved;
        $isActiveOrSigned = in_array($contractStatus, ['active', 'completed', 'approved', 'escrow_paid', 'signed_final'], true)
            || ($clientSigned && $creatorSigned);

        $agreedPrice = (float) ($contract->agreed_price ?? 0);
        $formattedPrice = 'Rp ' . number_format($agreedPrice, 0, ',', '.');
        $rawTerms = !empty($contract->dynamic_terms)
            ? array_values((array) $contract->dynamic_terms)
            : (!empty($contract->terms) ? [(string) $contract->terms] : []);

        $descParts = array_filter([
            trim((string) ($contract->description ?? '')),
            "Pihak Pertama: {$clientName} • Pihak Kedua: {$creatorName}",
            $agreedPrice > 0 ? "Nilai Kontrak: {$formattedPrice}" : null,
        ]);

        $publishedAt = ($contract->started_at ?? $contract->client_signed_at ?? $contract->created_at)?->toIso8601String();
        $createdAt = $contract->created_at?->toIso8601String();
        $docDate = ($contract->deadline ?? $contract->scheduled_end_date ?? $contract->created_at)?->format('Y-m-d');

        return [
            'id' => 'project-contract-' . $contract->id,
            'user_id' => $contract->client_id,
            'resource_type' => 'documents',
            'title' => 'Kontrak Proyek - ' . $contract->title,
            'description' => implode("\n", $descParts),
            'status' => $contractStatus === 'draft' ? 'draft' : 'published',
            'published_at' => $publishedAt,
            'created_at' => $createdAt,
            'updated_at' => ($contract->updated_at ?? $contract->created_at)?->toIso8601String(),
            'is_linked_project_document' => true,
            'metadata' => [
                'source_type' => 'project_contract',
                'source_label' => 'Proyek Saya',
                'category' => 'Kontrak Kerja Proyek (MoU / SPK)',
                'authority' => 'CV Transforma Alam Kreasi — Aplikasi Kreavana',
                'author' => "{$clientName} & {$creatorName}",
                'document_number' => $contractNumber,
                'contract_number' => $contractNumber,
                'contract_id' => $contract->id,
                'opportunity_id' => $contract->opportunity_id,
                'project_title' => $contract->title,
                'document_date' => $docDate,
                'file_format' => 'PDF',
                'file_size' => 'Kontrak Digital',
                'agreed_price' => $agreedPrice,
                'agreed_price_formatted' => $formattedPrice,
                'contract_status' => $contractStatus,
                'client_name' => $clientName,
                'client_username' => $contract->client?->username,
                'creator_name' => $creatorName,
                'creator_username' => $contract->creator?->username,
                'client_signed' => $clientSigned,
                'creator_signed' => $creatorSigned,
                'dynamic_terms' => $rawTerms,
                'verified' => $isActiveOrSigned,
                'locked_after_approval' => true,
                'readonly' => true,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function mapApplicationToContractDocument(Opportunity $opp, OpportunityApplication $app): array
    {
        $contractNumber = trim((string) ($app->contract_number ?? ''));
        if ($contractNumber === '') {
            $dateRef = $app->reviewed_at ?? $app->created_at ?? now();
            $contractNumber = sprintf(
                'KRV/CTR/%s/%s-%s',
                $dateRef->format('Y'),
                strtoupper(substr(str_replace('-', '', (string) $opp->id), 0, 4)),
                strtoupper(substr(str_replace('-', '', (string) $app->id), 0, 4)),
            );
        }

        $clientName = $opp->user?->name ?? 'Penyelenggara Proyek';
        $creatorName = $app->creator?->name ?? 'Pelamar / Kreator';
        $agreedPrice = (float) ($app->counter_offer_price ?: $app->bid_price ?: $opp->escrow_amount ?: 0);
        $formattedPrice = 'Rp ' . number_format($agreedPrice, 0, ',', '.');
        $clientSigned = !empty($app->client_signature) || !empty($opp->client_signature);
        $creatorSigned = !empty($app->creator_signature);
        $isPublished = $app->status === 'approved' || ($clientSigned && $creatorSigned);
        $docDate = ($app->reviewed_at ?? $opp->deadline ?? $app->created_at)?->format('Y-m-d');

        return [
            'id' => 'project-app-contract-' . $app->id,
            'user_id' => $opp->posted_by,
            'resource_type' => 'documents',
            'title' => 'Kontrak Proyek - ' . $opp->title,
            'description' => "Dokumen perjanjian kerja proyek \"{$opp->title}\" antara {$clientName} dan {$creatorName}."
                . ($agreedPrice > 0 ? "\nNilai Kesepakatan: {$formattedPrice}" : ''),
            'status' => $isPublished ? 'published' : 'draft',
            'published_at' => ($app->reviewed_at ?? $app->created_at)?->toIso8601String(),
            'created_at' => $app->created_at?->toIso8601String(),
            'updated_at' => ($app->updated_at ?? $app->created_at)?->toIso8601String(),
            'is_linked_project_document' => true,
            'metadata' => [
                'source_type' => 'project_application_contract',
                'source_label' => 'Proyek Saya',
                'category' => 'Kontrak Kerja Proyek (MoU / SPK)',
                'authority' => 'CV Transforma Alam Kreasi — Aplikasi Kreavana',
                'author' => "{$clientName} & {$creatorName}",
                'document_number' => $contractNumber,
                'contract_number' => $contractNumber,
                'application_id' => $app->id,
                'opportunity_id' => $opp->id,
                'project_title' => $opp->title,
                'document_date' => $docDate,
                'file_format' => 'PDF',
                'file_size' => 'Kontrak Digital',
                'agreed_price' => $agreedPrice,
                'agreed_price_formatted' => $formattedPrice,
                'client_name' => $clientName,
                'client_username' => $opp->user?->username,
                'creator_name' => $creatorName,
                'creator_username' => $app->creator?->username,
                'client_signed' => $clientSigned,
                'creator_signed' => $creatorSigned,
                'dynamic_terms' => array_values((array) (!empty($app->dynamic_terms) ? $app->dynamic_terms : ($opp->dynamic_terms ?? []))),
                'verified' => $clientSigned && $creatorSigned,
                'locked_after_approval' => true,
                'readonly' => true,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function mapOpportunityWetMou(Opportunity $opp): array
    {
        $url = trim((string) $opp->wet_signature_document_url);
        $path = (string) parse_url($url, PHP_URL_PATH);
        $fileName = basename($path) ?: 'Dokumen-MoU-TTD-Basah.pdf';
        $ext = strtoupper((string) pathinfo($fileName, PATHINFO_EXTENSION)) ?: 'PDF';
        $isVerified = !empty($opp->wet_signature_verified_at)
            || in_array($opp->meeting_status, ['verified_completed', 'verified_paid'], true);
        $ownerName = $opp->user?->name ?? 'Penyelenggara Proyek';
        $docNumber = 'MOU-PRJ-' . strtoupper(substr(str_replace('-', '', (string) $opp->id), 0, 8));

        return [
            'id' => 'project-wet-mou-' . $opp->id,
            'user_id' => $opp->posted_by,
            'resource_type' => 'documents',
            'title' => 'MoU Tanda Tangan Basah - ' . $opp->title,
            'description' => "Berkas Perjanjian Kerjasama Legal (MoU Fisik 3 Pihak) untuk proyek \"{$opp->title}\"."
                . (!empty($opp->meeting_notes) ? "\n\nCatatan: " . trim((string) $opp->meeting_notes) : ''),
            'status' => $isVerified ? 'published' : 'draft',
            'published_at' => ($opp->wet_signature_verified_at ?? $opp->created_at)?->toIso8601String(),
            'created_at' => $opp->created_at?->toIso8601String(),
            'updated_at' => ($opp->wet_signature_verified_at ?? $opp->created_at)?->toIso8601String(),
            'is_linked_project_document' => true,
            'metadata' => [
                'source_type' => 'project_wet_mou',
                'source_label' => 'Proyek Saya',
                'category' => 'MoU Proyek (TTD Basah)',
                'authority' => $ownerName,
                'author' => $ownerName,
                'document_number' => $docNumber,
                'opportunity_id' => $opp->id,
                'project_title' => $opp->title,
                'document_date' => ($opp->wet_signature_verified_at ?? $opp->created_at)?->format('Y-m-d'),
                'url' => $url,
                'file_url' => $url,
                'file_name' => $fileName,
                'file_format' => $ext,
                'file_size' => 'Dokumen Legal Proyek',
                'verified' => $isVerified,
                'locked_after_approval' => true,
                'readonly' => true,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function mapOpportunityAcceptanceLetter(Opportunity $opp): array
    {
        $url = trim((string) $opp->official_acceptance_letter_url);
        $path = (string) parse_url($url, PHP_URL_PATH);
        $fileName = trim((string) ($opp->official_acceptance_letter_name ?? ''))
            ?: (basename($path) ?: 'Surat_Resmi_Penerimaan.pdf');
        $ext = strtoupper((string) pathinfo($fileName, PATHINFO_EXTENSION)) ?: 'PDF';
        $ownerName = $opp->user?->name ?? 'Penyelenggara Program';
        $docNumber = 'SRT-PRJ-' . strtoupper(substr(str_replace('-', '', (string) $opp->id), 0, 8));

        return [
            'id' => 'project-letter-' . $opp->id,
            'user_id' => $opp->posted_by,
            'resource_type' => 'documents',
            'title' => 'Surat Resmi Penerimaan - ' . $opp->title,
            'description' => "Surat resmi penerimaan yang diterbitkan pada program/proyek \"{$opp->title}\".",
            'status' => 'published',
            'published_at' => ($opp->official_acceptance_letter_uploaded_at ?? $opp->created_at)?->toIso8601String(),
            'created_at' => ($opp->official_acceptance_letter_uploaded_at ?? $opp->created_at)?->toIso8601String(),
            'updated_at' => ($opp->official_acceptance_letter_uploaded_at ?? $opp->created_at)?->toIso8601String(),
            'is_linked_project_document' => true,
            'metadata' => [
                'source_type' => 'project_official_letter',
                'source_label' => 'Proyek Saya',
                'category' => 'Surat Resmi Penerimaan',
                'authority' => $ownerName,
                'author' => $ownerName,
                'document_number' => $docNumber,
                'opportunity_id' => $opp->id,
                'project_title' => $opp->title,
                'document_date' => ($opp->official_acceptance_letter_uploaded_at ?? $opp->created_at)?->format('Y-m-d'),
                'url' => $url,
                'file_url' => $url,
                'file_name' => $fileName,
                'file_format' => $ext,
                'file_size' => 'Surat Resmi',
                'verified' => true,
                'locked_after_approval' => true,
                'readonly' => true,
            ],
        ];
    }

    /**
     * @param  array<string, mixed>  $entry
     * @param  array<string, bool>  $seenUrls
     * @return array<string, mixed>|null
     */
    private function mapAttachmentEntry(
        string $id,
        string $userId,
        string $projectTitle,
        ?string $opportunityId,
        ?string $contractId,
        string $sourceType,
        string $category,
        string $authorName,
        array $entry,
        string $scopeKey,
        array &$seenUrls,
    ): ?array {
        $url = '';
        foreach (['url', 'file_url', 'document_url', 'attachment_url'] as $key) {
            $candidate = trim((string) ($entry[$key] ?? ''));
            if ($candidate !== '') {
                $url = $candidate;
                break;
            }
        }

        if ($url === '') {
            return null;
        }

        $dedupeKey = $scopeKey . ':' . strtolower($url);
        if (isset($seenUrls[$dedupeKey])) {
            return null;
        }
        $seenUrls[$dedupeKey] = true;

        $path = (string) parse_url($url, PHP_URL_PATH);
        $basename = basename($path) ?: 'Dokumen-Proyek';
        $entryTitle = '';
        foreach (['title', 'filename', 'file_name', 'name'] as $titleKey) {
            $candidate = trim((string) ($entry[$titleKey] ?? ''));
            if ($candidate !== '') {
                $entryTitle = $candidate;
                break;
            }
        }
        if ($entryTitle === '') {
            $entryTitle = $basename;
        }

        $ext = strtoupper(trim((string) ($entry['extension'] ?? pathinfo($basename, PATHINFO_EXTENSION))));
        if ($ext === '') {
            $ext = strtoupper(trim((string) ($entry['type'] ?? 'LINK')));
        }
        $notes = trim((string) ($entry['notes'] ?? $entry['note'] ?? $entry['description'] ?? ''));
        $createdAt = trim((string) ($entry['created_at'] ?? '')) ?: now()->toIso8601String();
        $docNumber = 'PRJ-DOC-' . strtoupper(substr(md5($id), 0, 8));

        return [
            'id' => $id,
            'user_id' => $userId,
            'resource_type' => 'documents',
            'title' => $entryTitle . ' — ' . $projectTitle,
            'description' => $notes !== ''
                ? "{$notes}\n\nProyek: {$projectTitle}"
                : "Berkas dokumen yang diunggah pada proyek \"{$projectTitle}\".",
            'status' => 'published',
            'published_at' => $createdAt,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
            'is_linked_project_document' => true,
            'metadata' => [
                'source_type' => $sourceType,
                'source_label' => 'Proyek Saya',
                'category' => $category,
                'authority' => $authorName,
                'author' => $authorName,
                'document_number' => $docNumber,
                'opportunity_id' => $opportunityId,
                'contract_id' => $contractId,
                'project_title' => $projectTitle,
                'document_date' => substr($createdAt, 0, 10),
                'url' => $url,
                'file_url' => $url,
                'file_name' => $basename,
                'file_format' => $ext,
                'file_size' => trim((string) ($entry['filesize'] ?? $entry['file_size'] ?? 'Dokumen Proyek')) ?: 'Dokumen Proyek',
                'verified' => true,
                'locked_after_approval' => true,
                'readonly' => true,
            ],
        ];
    }
}
