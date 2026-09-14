<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;

class StoreOpportunityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => 'required|string|max:200',
            'description' => 'nullable|string',
            'sub_role_slug' => 'nullable|string|max:50',
            'type' => 'required|in:location,project',
            'location' => 'nullable|string|max:100',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'location_category' => 'nullable|string|max:50',
            'address' => 'nullable|string|max:255',
            'deadline' => 'nullable|date',
            'event_date' => 'nullable|date',
            'event_start_time' => 'nullable|string',
            'event_end_time' => 'nullable|string',
            'budget_range' => 'nullable|string|max:100',
            'poster' => 'nullable|image|mimes:jpeg,png,jpg,gif,webp|max:5120',
            'requirements' => 'nullable|array',
            'requirements.*.sub_role_slug' => 'required_with:requirements|string|max:50',
            'requirements.*.quantity' => 'nullable|integer|min:1|max:50',
            'requirements.*.notes' => 'nullable|string|max:255',
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
