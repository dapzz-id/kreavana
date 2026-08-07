<?php

namespace App\Http\Controllers;

use App\Models\UserAddress;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class UserAddressController extends Controller
{
    public function index()
    {
        $addresses = UserAddress::where('user_id', Auth::id())
            ->orderByDesc('is_default')
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'status' => true,
            'data' => $addresses,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'label' => 'sometimes|string|max:50',
            'recipient_name' => 'required|string|max:150',
            'phone' => 'required|string|max:25',
            'address' => 'required|string|max:500',
            'city' => 'required|string|max:100',
            'province' => 'required|string|max:100',
            'postal_code' => 'required|string|max:10',
            'is_default' => 'sometimes|boolean',
        ]);

        $makeDefault = $request->boolean('is_default', false);
        if ($makeDefault) {
            UserAddress::where('user_id', Auth::id())->update(['is_default' => false]);
        }

        $address = UserAddress::create([
            'user_id' => Auth::id(),
            'label' => $request->label ?? 'Rumah',
            'recipient_name' => $request->recipient_name,
            'phone' => $request->phone,
            'address' => $request->address,
            'city' => $request->city,
            'province' => $request->province,
            'postal_code' => $request->postal_code,
            'is_default' => $makeDefault || ! UserAddress::where('user_id', Auth::id())->exists(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Alamat berhasil ditambahkan.',
            'data' => $address,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $address = UserAddress::where('user_id', Auth::id())->findOrFail($id);

        $request->validate([
            'label' => 'sometimes|string|max:50',
            'recipient_name' => 'sometimes|string|max:150',
            'phone' => 'sometimes|string|max:25',
            'address' => 'sometimes|string|max:500',
            'city' => 'sometimes|string|max:100',
            'province' => 'sometimes|string|max:100',
            'postal_code' => 'sometimes|string|max:10',
            'is_default' => 'sometimes|boolean',
        ]);

        $makeDefault = $request->has('is_default') ? $request->boolean('is_default') : $address->is_default;
        if ($makeDefault) {
            UserAddress::where('user_id', Auth::id())->where('id', '!=', $address->id)->update(['is_default' => false]);
        }

        $address->update($request->only([
            'label', 'recipient_name', 'phone', 'address', 'city', 'province', 'postal_code',
        ]) + ['is_default' => $makeDefault]);

        return response()->json([
            'status' => true,
            'message' => 'Alamat berhasil diperbarui.',
            'data' => $address,
        ]);
    }

    public function setDefault($id)
    {
        $address = UserAddress::where('user_id', Auth::id())->findOrFail($id);

        UserAddress::where('user_id', Auth::id())->update(['is_default' => false]);
        $address->update(['is_default' => true]);

        return response()->json([
            'status' => true,
            'message' => 'Alamat utama berhasil diatur.',
            'data' => $address,
        ]);
    }

    public function destroy($id)
    {
        $address = UserAddress::where('user_id', Auth::id())->findOrFail($id);
        $address->delete();

        return response()->json([
            'status' => true,
            'message' => 'Alamat berhasil dihapus.',
        ]);
    }
}
