<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Validation\Rules\Enum;
use Illuminate\Support\Facades\Auth;
use App\Enums\CreatorSubRole;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $userId = $this->user()?->id ?? Auth::guard('api')->id() ?? $this->input('user_id');

        return [
            'name' => 'sometimes|string|min:2|max:100',
            'phone' => 'nullable|string|max:35',
            'username' => 'sometimes|string|min:3|max:50|unique:users,username,' . $userId,
            'email' => 'sometimes|email|max:150|unique:users,email,' . $userId,
            'sub_role' => ['sometimes', new Enum(CreatorSubRole::class)],
            'avatar_url' => 'sometimes|string',
            'max_work_capacity' => 'sometimes|nullable|integer|min:0|max:10000',
        ];
    }

    public function messages(): array
    {
        return [
            'username.min' => 'Username minimal 3 karakter.',
            'username.max' => 'Username maksimal 50 karakter.',
            'username.unique' => 'Username ini sudah digunakan pengguna lain.',
            'email.email' => 'Format email tidak valid.',
            'email.unique' => 'Email ini sudah digunakan pengguna lain.',
            'phone.regex' => 'Nomor telepon tidak valid.',
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(response()->json([
            'status' => false,
            'message' => $validator->errors()->first(),
        ], 422));
    }
}
