<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Enum;
use Illuminate\Support\Facades\Auth;
use App\Enums\CreatorSubRole;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $updates = [];

        if ($this->has('username') && is_string($this->input('username'))) {
            $trimmedUsername = strtolower(trim($this->input('username')));
            if ($trimmedUsername !== '') {
                $updates['username'] = $trimmedUsername;
            }
        }

        if ($this->has('email') && is_string($this->input('email'))) {
            $trimmedEmail = strtolower(trim($this->input('email')));
            if ($trimmedEmail !== '') {
                $updates['email'] = $trimmedEmail;
            }
        }

        if ($this->has('phone')) {
            $trimmedPhone = trim((string) ($this->input('phone') ?? ''));
            $updates['phone'] = $trimmedPhone !== '' ? $trimmedPhone : null;
        }

        if ($this->has('name') && is_string($this->input('name'))) {
            $updates['name'] = trim($this->input('name'));
        }

        if (!empty($updates)) {
            $this->merge($updates);
        }
    }

    public function rules(): array
    {
        $userId = $this->user()?->id ?? Auth::guard('api')->id() ?? $this->input('user_id');

        return [
            'name' => 'sometimes|string|min:2|max:100',
            'phone' => 'nullable|string|max:35',
            'username' => [
                'sometimes',
                'string',
                'min:3',
                'max:50',
                'regex:/^[a-zA-Z0-9_.-]+$/',
                Rule::unique('users', 'username')->ignore($userId),
            ],
            'email' => [
                'sometimes',
                'email',
                'max:150',
                Rule::unique('users', 'email')->ignore($userId),
            ],
            'sub_role' => ['sometimes', new Enum(CreatorSubRole::class)],
            'avatar_url' => 'sometimes|string',
            'max_work_capacity' => 'sometimes|nullable|integer|min:0|max:10000',
        ];
    }

    public function messages(): array
    {
        return [
            'name.min' => 'Nama lengkap minimal 2 karakter.',
            'name.max' => 'Nama lengkap maksimal 100 karakter.',
            'username.min' => 'Username minimal 3 karakter.',
            'username.max' => 'Username maksimal 50 karakter.',
            'username.regex' => 'Username hanya boleh berisi huruf, angka, titik, strip, dan underscore.',
            'username.unique' => 'Username ini sudah digunakan pengguna lain.',
            'email.email' => 'Format email tidak valid.',
            'email.unique' => 'Email ini sudah digunakan pengguna lain.',
            'phone.max' => 'Nomor telepon maksimal 35 karakter.',
            'phone.regex' => 'Nomor telepon tidak valid.',
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(response()->json([
            'status' => false,
            'message' => $validator->errors()->first(),
            'errors' => $validator->errors(),
        ], 422));
    }
}
