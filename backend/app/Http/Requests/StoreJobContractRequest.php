<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class StoreJobContractRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'partner_id' => 'required|uuid|exists:users,id',
            'my_role' => 'required|in:client,creator',
            'opportunity_id' => 'nullable|uuid|exists:opportunities,id',
            'marketplace_item_id' => 'nullable|uuid|exists:marketplace_items,id',
            'title' => 'required_without:marketplace_item_id|string|max:200',
            'description' => 'nullable|string',
            'terms' => 'nullable|string',
            'agreed_price' => 'required_without:marketplace_item_id|numeric|min:0',
            'deadline' => 'nullable|date',
            'scheduled_start_date' => 'required|date',
            'scheduled_end_date' => 'required|date|after_or_equal:scheduled_start_date',
        ];
    }
}
