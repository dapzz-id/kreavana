<?php

namespace App\Http\Controllers;

use App\Repositories\Contracts\PhotoRepositoryInterface;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/**
 * CartController — Shopping Cart Management
 *
 * SRP : Handles only the session-based shopping cart operations.
 * DIP : Depends on PhotoRepositoryInterface for photo retrieval instead of Eloquent models directly.
 */
class CartController extends Controller
{
    public function __construct(
        private readonly PhotoRepositoryInterface $photoRepository
    ) {}

    /**
     * Show cart items.
     */
    public function index()
    {
        $cart     = session()->get('cart', []);
        $photos   = [];
        $subtotal = 0.00;
        $adminFee = 0.00;
        $total    = 0.00;

        if (!empty($cart)) {
            $photos   = $this->photoRepository->getByIdsWithRelations($cart, ['photographer']);
            $subtotal = $photos->sum('price');
            $adminFee = 1000.00;
            $total    = $subtotal + $adminFee;
        }

        return view('cart', compact('photos', 'subtotal', 'adminFee', 'total'));
    }

    /**
     * Add a photo to the cart.
     */
    public function add(int $id)
    {
        $photo = $this->photoRepository->findById($id);

        if (!$photo) {
            abort(404, 'Foto tidak ditemukan.');
        }

        if ($photo->is_free) {
            return redirect()->back()->with('error', 'Foto ini gratis, Anda tidak perlu membelinya.');
        }

        if (Auth::check()) {
            $user = Auth::user();

            if ($photo->user_id === $user->id) {
                return redirect()->back()->with('error', 'Anda tidak dapat membeli foto Anda sendiri.');
            }

            if ($user->hasPurchased($photo->id)) {
                return redirect()->back()->with('error', 'Anda sudah membeli foto ini sebelumnya.');
            }
        }

        $cart = session()->get('cart', []);

        if (in_array($id, $cart)) {
            return redirect()->route('cart.index')->with('info', 'Foto sudah berada di dalam keranjang.');
        }

        $cart[] = $id;
        session()->put('cart', $cart);

        return redirect()->route('cart.index')->with('success', 'Foto ditambahkan ke keranjang belanja.');
    }

    /**
     * Remove an item from the cart.
     */
    public function remove(int $id)
    {
        $cart = session()->get('cart', []);

        if (($key = array_search($id, $cart)) !== false) {
            unset($cart[$key]);
            session()->put('cart', array_values($cart));
        }

        return redirect()->route('cart.index')->with('success', 'Foto dihapus dari keranjang.');
    }

    /**
     * Empty the cart.
     */
    public function clear()
    {
        session()->forget('cart');
        return redirect()->route('cart.index')->with('success', 'Keranjang dibersihkan.');
    }
}
