<?php

namespace App\Http\Controllers;

use App\Models\PaymentMethod;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class PaymentMethodController extends Controller
{
    public function index()
    {
        $methods = PaymentMethod::where('user_id', Auth::id())
            ->orderByDesc('is_default')
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'status' => true,
            'data' => $methods,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'type' => 'required|string|in:bank,ewallet',
            'provider' => 'required|string|max:100',
            'account_name' => 'required|string|max:150',
            'account_number' => 'required|string|max:50',
            'is_default' => 'sometimes|boolean',
        ]);

        $makeDefault = $request->boolean('is_default', false);
        if ($makeDefault) {
            PaymentMethod::where('user_id', Auth::id())->update(['is_default' => false]);
        }

        $method = PaymentMethod::create([
            'user_id' => Auth::id(),
            'type' => $request->type,
            'provider' => $request->provider,
            'account_name' => $request->account_name,
            'account_number' => $request->account_number,
            'is_default' => $makeDefault || ! PaymentMethod::where('user_id', Auth::id())->exists(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Metode pembayaran berhasil ditambahkan.',
            'data' => $method,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $method = PaymentMethod::where('user_id', Auth::id())->findOrFail($id);

        $request->validate([
            'type' => 'sometimes|string|in:bank,ewallet',
            'provider' => 'sometimes|string|max:100',
            'account_name' => 'sometimes|string|max:150',
            'account_number' => 'sometimes|string|max:50',
            'is_default' => 'sometimes|boolean',
        ]);

        $makeDefault = $request->has('is_default') ? $request->boolean('is_default') : $method->is_default;
        if ($makeDefault) {
            PaymentMethod::where('user_id', Auth::id())->where('id', '!=', $method->id)->update(['is_default' => false]);
        }

        $method->update($request->only([
            'type', 'provider', 'account_name', 'account_number',
        ]) + ['is_default' => $makeDefault]);

        return response()->json([
            'status' => true,
            'message' => 'Metode pembayaran berhasil diperbarui.',
            'data' => $method,
        ]);
    }

    public function setDefault($id)
    {
        $method = PaymentMethod::where('user_id', Auth::id())->findOrFail($id);

        PaymentMethod::where('user_id', Auth::id())->update(['is_default' => false]);
        $method->update(['is_default' => true]);

        return response()->json([
            'status' => true,
            'message' => 'Metode pembayaran utama berhasil diatur.',
            'data' => $method,
        ]);
    }

    public function destroy($id)
    {
        $method = PaymentMethod::where('user_id', Auth::id())->findOrFail($id);
        $method->delete();

        return response()->json([
            'status' => true,
            'message' => 'Metode pembayaran berhasil dihapus.',
        ]);
    }
}
