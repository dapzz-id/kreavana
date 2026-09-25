<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;
use App\Enums\CreatorSubRole;

class ApplyCreatorRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $reuseKtp = filter_var($this->input('reuse_ktp'), FILTER_VALIDATE_BOOLEAN);

        return [
            'sub_role_category' => ['required', 'string', 'in:' . implode(',', array_column(CreatorSubRole::cases(), 'value'))],
            'skill_description' => 'required|string|min:20|max:2000',
            'portfolio_link' => 'required|url|max:255',
            'experience' => 'nullable|string|max:2000',
            'reuse_ktp' => 'nullable|boolean',
            'nib_number' => 'nullable|string|max:50',
            'nib_file_url' => 'nullable|string',
            'nik' => $reuseKtp ? 'nullable|regex:/^\d{16}$/' : 'required|regex:/^\d{16}$/',
            'full_name_ktp' => $reuseKtp ? 'nullable|string|min:3|max:150' : 'required|string|min:3|max:150',
            'birth_place' => $reuseKtp ? 'nullable|string|min:2|max:100' : 'required|string|min:2|max:100',
            'birth_date' => $reuseKtp ? 'nullable|date|date_format:Y-m-d|before:today' : 'required|date|date_format:Y-m-d|before:today',
            'address_ktp' => $reuseKtp ? 'nullable|string|min:10|max:500' : 'required|string|min:10|max:500',
            'ktp_photo_url' => $reuseKtp ? 'nullable|string' : 'required|string',
            'selfie_photo_url' => $reuseKtp ? 'nullable|string' : 'required|string',
        ];
    }

    public function messages(): array
    {
        return [
            'nik.regex' => 'NIK harus 16 digit angka.',
            'full_name_ktp.regex' => 'Nama KTP hanya boleh huruf dan spasi.',
            'birth_place.regex' => 'Tempat lahir hanya boleh huruf.',
            'birth_date.before' => 'Tanggal lahir tidak valid.',
            'portfolio_link.url' => 'Link portfolio harus URL valid (https://...).',
            'skill_description.min' => 'Deskripsi keahlian minimal 20 karakter.',
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
