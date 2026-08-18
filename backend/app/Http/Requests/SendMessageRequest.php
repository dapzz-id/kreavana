<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;

class SendMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => 'required|string|in:text,audio',
            'media' => 'required_if:type,audio|string|nullable',
            'reply_to_id' => 'nullable|uuid',
            
            // E2EE fields
            'encryption_version' => 'nullable|integer|in:0,1',
            'ciphertext' => 'required_if:encryption_version,1|string|nullable',
            'iv' => 'required_if:encryption_version,1|string|nullable',
            
            // Message keys must be provided if version 1
            'message_keys' => 'required_if:encryption_version,1|array',
            'message_keys.*.device_id' => 'required_with:message_keys|string',
            'message_keys.*.encrypted_key' => 'required_with:message_keys|string',

            // Plaintext message must NOT be present if version 1
            // But if version 0, it's required (unless audio)
        ];
    }
    
    public function withValidator($validator)
    {
        $validator->after(function ($validator) {
            $version = (int) $this->input('encryption_version', 0);
            $message = $this->input('message');
            $type = $this->input('type');
            $media = $this->input('media');
            
            if ($version === 1) {
                // If version 1, plaintext message is NOT allowed to have actual content
                if (!empty($message)) {
                    $validator->errors()->add('message', 'Plaintext message is not allowed in encrypted payload.');
                }
            } else {
                // If version 0, normal validation applies
                if (empty($message) && empty($media) && $type !== 'audio') {
                    $validator->errors()->add('message', 'The message field is required.');
                }
            }
        });
    }

    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(response()->json([
            'status' => false,
            'message' => $validator->errors()->first(),
        ], 422));
    }
}
