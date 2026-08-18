<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Validation\Rules\Enum;
use App\Enums\CreatorSubRole;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => 'sometimes|string|min:2|max:100',
            'phone' => 'nullable|regex:/^(\+62|62|0)8[0-9]{8,11}$/',
            'sub_role' => ['sometimes', new Enum(CreatorSubRole::class)],
            'avatar_url' => 'sometimes|string',
            'max_work_capacity' => 'sometimes|nullable|integer|min:0|max:10000',
        ];
    }

    public function messages(): array
    {
        return [
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
