<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Repositories\Contracts\RoleRepositoryInterface;
use App\Repositories\Contracts\UserRepositoryInterface;
use App\Services\LedgerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function __construct(
        private readonly RoleRepositoryInterface $roleRepository,
        private readonly UserRepositoryInterface $userRepository,
        private readonly LedgerService           $ledgerService,
    ) {}

    public function showLogin()
    {
        if (Auth::check()) {
            return redirect()->route('dashboard');
        }
        return view('auth.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        if (Auth::attempt($credentials, $request->boolean('remember'))) {
            $request->session()->regenerate();
            return redirect()->intended(route('dashboard'))->with('success', 'Selamat datang kembali!');
        }

        return back()->withErrors([
            'email' => 'Email atau password yang Anda masukkan salah.',
        ])->onlyInput('email');
    }

    public function showRegister()
    {
        if (Auth::check()) {
            return redirect()->route('dashboard');
        }
        return view('auth.register');
    }

    public function register(Request $request)
    {
        $request->validate([
            'name'                  => 'required|string|max:255',
            'email'                 => 'required|string|email|max:255|unique:users',
            'password'              => 'required|string|min:6|confirmed',
        ]);

        $userRole = $this->roleRepository->findBySlug('user');

        $user = $this->userRepository->create([
            'name'     => $request->name,
            'email'    => $request->email,
            'password' => Hash::make($request->password),
            'role_id'  => $userRole?->id,
        ]);

        // Initialize ledger balance with Rp 0
        $this->ledgerService->addTransaction($user, 0.00, 'deposit', 'registration_init');

        Auth::login($user);

        return redirect()->route('dashboard')->with('success', 'Registrasi berhasil! Selamat bergabung.');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        return redirect()->route('explore')->with('success', 'Anda telah keluar.');
    }

    /**
     * Redirect the user to the Google authentication page.
     */
    public function redirectToGoogle()
    {
        return \Laravel\Socialite\Facades\Socialite::driver('google')->redirect();
    }

    /**
     * Obtain the user information from Google.
     */
    public function handleGoogleCallback()
    {
        try {
            $googleUser = \Laravel\Socialite\Facades\Socialite::driver('google')->user();
            
            $user = User::where('google_id', $googleUser->getId())
                        ->orWhere('email', $googleUser->getEmail())
                        ->first();

            if ($user) {
                if (!$user->google_id) {
                    $user->update(['google_id' => $googleUser->getId()]);
                }
                Auth::login($user);
                return redirect()->intended(route('explore'))->with('success', 'Selamat datang kembali!');
            }

            $userRole = $this->roleRepository->findBySlug('user');
            
            $newUser = $this->userRepository->create([
                'name' => $googleUser->getName(),
                'email' => $googleUser->getEmail(),
                'google_id' => $googleUser->getId(),
                'password' => null, // No password for Google login
                'role_id' => $userRole?->id,
            ]);

            // Initialize ledger balance with Rp 0
            $this->ledgerService->addTransaction($newUser, 0.00, 'deposit', 'registration_init');

            Auth::login($newUser);

            return redirect()->route('explore')->with('success', 'Registrasi berhasil! Selamat bergabung.');

        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('Google Login Error: ' . $e->getMessage());
            return redirect()->route('login')->withErrors(['email' => 'Gagal login menggunakan Google. Silakan coba lagi.']);
        }
    }
}
