<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Services\OpportunityService;
use App\Http\Requests\StoreOpportunityRequest;
use App\Http\Requests\SubmitReportRequest;
use App\Traits\ApiResponse;
use App\Models\User;

class OpportunityController extends Controller
{
    use ApiResponse;

    protected OpportunityService $opportunityService;

    public function __construct(OpportunityService $opportunityService)
    {
        $this->opportunityService = $opportunityService;
    }

    public function index(Request $request)
    {
        $subRoles = $request->query('sub_roles') ?? $request->query('sub_role_slug', 'all');
        $type = $request->query('type');
        $limit = (int) $request->query('limit', 50);
        $search = $request->query('search');

        $opportunities = $this->opportunityService->getList($subRoles, $type, $limit, $search);

        return $this->successResponse('Data peluang berhasil diambil', $opportunities->toArray());
    }

    public function mapLocations(Request $request)
    {
        $subRoles = $request->query('sub_roles') ?? $request->query('sub_role_slug', 'all');
        $lat = $request->has('lat') ? (float) $request->query('lat') : null;
        $lng = $request->has('lng') ? (float) $request->query('lng') : null;
        $radiusKm = $request->has('radius_km') ? (float) $request->query('radius_km') : null;

        $locations = $this->opportunityService->getMapLocations($subRoles, $lat, $lng, $radiusKm);

        return $this->successResponse('Data lokasi peluang berhasil diambil', $locations->toArray());
    }

    public function show($id)
    {
        $opp = $this->opportunityService->findById($id);

        if (!$opp) {
            return $this->errorResponse('Peluang tidak ditemukan.', 404);
        }

        return $this->successResponse('Detail peluang berhasil diambil', $opp);
    }

    public function myOpportunities(Request $request)
    {
        $user = Auth::guard('api')->user() ?? $request->user();
        if (!$user) {
            return $this->errorResponse('Unauthenticated.', 401);
        }

        $limit = (int) $request->query('limit', 50);
        $opportunities = $this->opportunityService->getUserOpportunities($user->id, $limit);

        return $this->successResponse('Daftar kebutuhan/proyek saya berhasil diambil', $opportunities->toArray());
    }

    public function store(StoreOpportunityRequest $request)
    {
        $user = Auth::guard('api')->user();

        if ($user) {
            $rawSub = $user->sub_role;
            $subRole = is_object($rawSub) && isset($rawSub->value) 
                ? strtolower(trim($rawSub->value)) 
                : strtolower(trim((string)$rawSub));

            if (in_array($subRole, ['institution', 'institusi', 'school', 'sekolah', 'kampus', 'campus', 'education'])) {
                return $this->errorResponse('Institusi Pendidikan tidak memiliki akses untuk membuka lowongan magang atau proyek. Program magang hanya dapat dibuka oleh akun Corporate / Mitra Industri.', 403);
            }
        }

        // Akun Corporate tidak memerlukan verifikasi KTP untuk membuka lowongan/proyek
        if ($user && $user->role->value === 'user' && !$user->isCorporate() && !$user->is_verified) {
            return $this->errorResponse('Klien wajib melakukan verifikasi KTP terlebih dahulu sebelum mempublikasikan kebutuhan proyek.', 403);
        }

        $posterFile = $request->file('poster');
        
        $opp = $this->opportunityService->createOpportunity($user->id, $request->validated(), $posterFile);

        return $this->successResponse('Peluang berhasil dibuat.', $opp, 201);
    }

    public function apply(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();

        $validated = $request->validate([
            'sub_role_slug' => 'required|string|max:50',
            'pitch_message' => 'required|string|min:10|max:2000',
            'questions_notes' => 'nullable|string|max:1000',
            'bid_price' => 'required|numeric|min:1',
        ]);

        try {
            $application = $this->opportunityService->applyToOpportunity($user->id, $id, $validated);
            return $this->successResponse('Lamaran berhasil diajukan. Pemilik proyek akan meninjau lamaran Anda.', $application, 201);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function applications(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();

        try {
            $applications = $this->opportunityService->getOpportunityApplications($id, $user->id);
            return $this->successResponse('Daftar pelamar berhasil diambil.', $applications);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function approveApplication(Request $request, string $applicationId)
    {
        $user = Auth::guard('api')->user();

        try {
            $result = $this->opportunityService->reviewApplication($applicationId, $user->id, 'approve');
            return $this->successResponse('Pelamar berhasil disetujui untuk proyek ini.', $result);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function rejectApplication(Request $request, string $applicationId)
    {
        $user = Auth::guard('api')->user();
        $reason = $request->input('reason');

        try {
            $result = $this->opportunityService->reviewApplication($applicationId, $user->id, 'reject', $reason);
            return $this->successResponse('Lamaran berhasil ditolak.', $result);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function considerApplication(Request $request, string $applicationId)
    {
        $user = Auth::guard('api')->user();
        $counterOfferPrice = $request->input('counter_offer_price');
        $notes = $request->input('notes') ?? $request->input('reason');

        if (!$counterOfferPrice || !is_numeric($counterOfferPrice) || (float) $counterOfferPrice <= 0) {
            return $this->errorResponse('Nominal tawaran dana harus berupa angka lebih dari 0.', 422);
        }

        try {
            $result = $this->opportunityService->reviewApplication(
                $applicationId,
                $user->id,
                'consider',
                null,
                (float) $counterOfferPrice,
                $notes
            );
            return $this->successResponse('Lamaran dialihkan ke status pertimbangan dengan tawaran dana baru.', $result);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function respondCounterOffer(Request $request, string $applicationId)
    {
        $user = Auth::guard('api')->user();
        $action = $request->input('action');

        if (!in_array($action, ['accept', 'decline', 'counter'])) {
            return $this->errorResponse('Tindakan tidak valid. Pilihan: accept, decline, atau counter.', 422);
        }

        $counterOfferPrice = $request->has('counter_offer_price') ? (float) $request->input('counter_offer_price') : null;
        $counterOfferNotes = $request->input('counter_offer_notes');

        try {
            $result = $this->opportunityService->respondCounterOffer(
                $applicationId,
                $user->id,
                $action,
                $counterOfferPrice,
                $counterOfferNotes
            );
            $msg = match ($action) {
                'accept' => 'Tawaran dana berhasil diterima. Lamaran kini siap difinalisasi oleh pemilik proyek.',
                'counter' => 'Penawaran balik berhasil diajukan kepada pemilik proyek.',
                'decline' => 'Tawaran dana telah ditolak.',
            };
            return $this->successResponse($msg, $result);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function submitReport(SubmitReportRequest $request)
    {
        $user = Auth::guard('api')->user();

        $this->opportunityService->submitReport($user->id, $request->validated());

        return $this->successResponse('Laporan berhasil dikirim. Tim kami akan meninjau segera.');
    }

    // Endpoint to fetch creator public profile information
    public function getPoster($id)
    {
        $opp = \App\Models\Opportunity::select('id', 'posted_by')->find($id);
        
        if (!$opp) {
            return $this->errorResponse('Peluang tidak ditemukan.', 404);
        }

        // Privacy safe: NEVER expose phone or email in public API
        $user = User::select('id', 'name', 'username', 'avatar_url', 'sub_role as selected_sub_role')->find($opp->posted_by);
        
        if (!$user) {
            return $this->errorResponse('Pembuat peluang tidak ditemukan.', 404);
        }

        return $this->successResponse('Data pembuat peluang berhasil diambil', $user->toArray());
    }
    public function complete(Request $request, $id)
    {
        $user = Auth::guard('api')->user();
        
        try {
            $opp = \Illuminate\Support\Facades\DB::transaction(function () use ($id, $user, $request) {
                $opp = \App\Models\Opportunity::where('id', $id)->lockForUpdate()->firstOrFail();

                if ($opp->status === 'closed') {
                    abort(409, 'Cannot refund or cancel a completed project.');
                }
                if ($opp->status === 'cancelled') {
                    abort(409, 'Project has been cancelled.');
                }

                // If user is the creator (seller of services, mapped to posted_by as per prompt instructions)
                if ($user->id === $opp->posted_by) {
                    if ($opp->creator_completed) {
                        abort(409, 'Creator has already confirmed completion.');
                    }
                    $opp->creator_completed = true;
                    $opp->creator_completed_at = now();
                    $opp->save();
                    return $opp;
                }

                // If user is the buyer (client)
                if ($user->id === $opp->buyer_id) {
                    if (!$opp->creator_completed) {
                        abort(409, 'Creator has not confirmed completion yet.');
                    }
                    
                    $request->validate(['pin' => 'required|string']);

                    if (!\Illuminate\Support\Facades\Hash::check($request->pin, $user->wallet_pin)) {
                        abort(400, 'PIN salah.');
                    }

                    $opp->buyer_completed = true;
                    $opp->status = 'closed';
                    $opp->save();

                    return $opp;
                }

                abort(403, 'Unauthorized. Hanya pihak terkait project yang dapat menyelesaikan.');
            });

            return $this->successResponse('Aksi penyelesaian berhasil.', $opp);
        } catch (\Exception $e) {
            $statusCode = $e instanceof \Symfony\Component\HttpKernel\Exception\HttpExceptionInterface ? $e->getStatusCode() : 500;
            return $this->errorResponse($e->getMessage(), $statusCode);
        }
    }

    public function signContract(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();

        $request->validate([
            'signature' => 'required|string',
        ]);

        try {
            $opp = $this->opportunityService->signContract($id, $user->id, $request->all());
            return $this->successResponse('Tanda tangan elektronik dynamic berhasil disimpan.', $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function updateDynamicTerms(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();

        $request->validate([
            'dynamic_terms' => 'required|array',
        ]);

        try {
            $opp = $this->opportunityService->updateDynamicTerms($id, $user->id, $request->input('dynamic_terms'));
            return $this->successResponse('Ketentuan khusus kontrak berhasil diperbarui.', $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function startEvent(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();

        try {
            $opp = $this->opportunityService->startEvent($id, $user->id, $request->all());
            return $this->successResponse('Acara berhasil dimulai! Status proyek kini berlangsung, tanda tangan telah sah, dan dana escrow telah diamankan.', $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function getContracts(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();

        try {
            $contracts = $this->opportunityService->getOpportunityContracts($id, $user->id);
            return $this->successResponse('Daftar kontrak digital dynamic 3 pihak berhasil dimuat.', $contracts);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function updateProgress(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'progress' => 'required|integer|min:0|max:100',
        ]);

        try {
            $opp = $this->opportunityService->updateProgress($id, $user->id, (int) $validated['progress']);
            return $this->successResponse('Progress acara berhasil diperbarui.', $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function submitDocuments(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'documents' => 'required|array',
            'documents.*.title' => 'required|string|max:150',
            'documents.*.url' => 'required|string|max:500',
            'documents.*.notes' => 'nullable|string|max:500',
        ]);

        try {
            $result = $this->opportunityService->submitDocuments($id, $user->id, $validated['documents']);
            return $this->successResponse('Dokumen / link berhasil dikirimkan.', $result);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function scheduleMeeting(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'meeting_date' => 'required|date',
            'meeting_time' => 'required|string|max:30',
            'meeting_location' => 'required|string|max:255',
            'meeting_lat' => 'nullable|numeric',
            'meeting_lng' => 'nullable|numeric',
            'meeting_notes' => 'nullable|string|max:1000',
        ]);

        try {
            $opp = $this->opportunityService->scheduleMeeting($id, $user->id, $validated);
            return $this->successResponse('Jadwal pertemuan fisik tanda tangan basah berhasil diajukan.', $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function reviewMeeting(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'decision' => 'required|in:approve,counter,reject',
            'notes' => 'nullable|string|max:1000',
            'counter_date' => 'nullable|date',
            'counter_time' => 'nullable|string|max:50',
            'counter_location' => 'nullable|string|max:500',
            'counter_lat' => 'nullable|numeric',
            'counter_lng' => 'nullable|numeric',
            'counter_notes' => 'nullable|string|max:1000',
        ]);

        try {
            $opp = $this->opportunityService->reviewMeeting($id, $user->id, $validated['decision'], $validated['notes'] ?? null, $validated);
            $msg = $validated['decision'] === 'approve'
                ? 'Jadwal pertemuan fisik disetujui. Status acara: Diproses.'
                : ($validated['decision'] === 'counter'
                    ? 'Tawaran nego jadwal dan lokasi alternatif berhasil dikirim ke pembuat acara.'
                    : 'Jadwal pertemuan fisik ditolak.');
            return $this->successResponse($msg, $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function respondMeetingCounter(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'action' => 'required|in:accept,counter,decline',
            'meeting_date' => 'nullable|date',
            'meeting_time' => 'nullable|string|max:50',
            'meeting_location' => 'nullable|string|max:500',
            'meeting_lat' => 'nullable|numeric',
            'meeting_lng' => 'nullable|numeric',
            'meeting_notes' => 'nullable|string|max:1000',
        ]);

        try {
            $opp = $this->opportunityService->respondMeetingCounter($id, $user->id, $validated['action'], $validated);
            $msg = $validated['action'] === 'accept'
                ? 'Jadwal usulan Admin disetujui. Status pertemuan: Diproses.'
                : ($validated['action'] === 'counter'
                    ? 'Tawaran balik jadwal dan lokasi berhasil dikirim ke Admin Kreavana.'
                    : 'Tawaran jadwal Admin ditolak.');
            return $this->successResponse($msg, $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function adminStartEvent(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'document_mou_url' => 'nullable|string|max:500',
            'notes' => 'nullable|string|max:1000',
        ]);

        try {
            $opp = $this->opportunityService->adminStartEvent($id, $user->id, $validated);
            return $this->successResponse('Acara resmi dimulai oleh Admin setelah verifikasi tanda tangan basah fisik!', $opp);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function updateWorkerProgress(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'progress' => 'required|integer|min:0|max:100',
            'notes' => 'nullable|string|max:1000',
            'worker_status' => 'nullable|string|max:40',
        ]);

        try {
            $res = $this->opportunityService->updateWorkerProgress($id, $user->id, (int) $validated['progress'], $validated['notes'] ?? null, $validated['worker_status'] ?? null);
            return $this->successResponse('Progress pekerja berhasil diperbarui.', $res);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function uploadDeliverable(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'type' => 'required|in:link,image,video,document',
            'url' => 'nullable|string|max:1000',
            'title' => 'required|string|max:200',
            'notes' => 'nullable|string|max:1000',
            'file' => 'nullable|file|max:51200', // Max 50MB
        ]);

        try {
            $file = $request->file('file');
            $res = $this->opportunityService->submitWorkerDeliverable($id, $user->id, $validated, $file);
            return $this->successResponse('Hasil kerja (deliverable) berhasil diunggah.', $res);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function payWorker(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();
        $validated = $request->validate([
            'milestone_index' => 'nullable|integer|min:0',
            'amount' => 'nullable|numeric|min:1',
        ]);

        try {
            $milestoneIndex = isset($validated['milestone_index']) ? (int) $validated['milestone_index'] : null;
            $amount = isset($validated['amount']) ? (float) $validated['amount'] : null;

            $res = $this->opportunityService->payWorkerTerm($id, $user->id, $milestoneIndex, $amount);
            return $this->successResponse('Pembayaran honor berhasil dicairkan ke saldo pekerja.', $res);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    public function autoReleaseEscrow(Request $request, string $id)
    {
        $user = Auth::guard('api')->user();

        try {
            $res = $this->opportunityService->checkAndAutoReleaseEscrow($id, $user->id);
            return $this->successResponse($res['message'], $res);
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            return $this->errorResponse($e->getMessage(), $e->getStatusCode());
        } catch (\Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }
}
