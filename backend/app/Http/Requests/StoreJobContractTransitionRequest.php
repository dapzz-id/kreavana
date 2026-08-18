<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreJobContractTransitionRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true; // Authorization is handled by the controller/service
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'transition' => 'required|string|in:approve,pay_escrow,submit_work,request_revision,approve_work,request_cancellation,confirm_cancellation,raise_dispute',
            'metadata' => 'nullable|array',
            'metadata.reason' => 'nullable|string|max:1000',
        ];
    }
}
