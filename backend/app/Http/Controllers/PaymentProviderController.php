<?php

namespace App\Http\Controllers;

use App\Models\PaymentProvider;
use Illuminate\Http\Request;

class PaymentProviderController extends Controller
{
    public function index(Request $request)
    {
        $query = PaymentProvider::active()->orderBy('sort_order')->orderBy('name');

        if ($request->has('type') && in_array($request->type, ['bank', 'ewallet'], true)) {
            $query->byType($request->type);
        }

        return response()->json([
            'status' => true,
            'data' => $query->get(),
        ]);
    }

    public function show($id)
    {
        $provider = PaymentProvider::active()->findOrFail($id);

        return response()->json([
            'status' => true,
            'data' => $provider,
        ]);
    }
}
