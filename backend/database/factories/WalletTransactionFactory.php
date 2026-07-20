<?php

namespace Database\Factories;

use App\Models\WalletTransaction;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<WalletTransaction>
 */
class WalletTransactionFactory extends Factory
{
    protected $model = WalletTransaction::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'type' => fake()->randomElement(['topup', 'payment', 'transfer', 'withdraw']),
            'amount' => fake()->randomFloat(2, 50000, 10000000),
            'fee' => fake()->randomFloat(2, 0, 10000),
            'payment_method' => fake()->randomElement(['bank_transfer', 'ewallet', 'credit_card']),
            'payment_provider' => fake()->randomElement(['bca', 'bni', 'mandiri', 'gopay', 'ovo']),
            'status' => fake()->randomElement(['completed', 'pending', 'failed']),
            'reference_number' => fake()->unique()->numerify('REF########'),
            'description' => fake()->sentence(5),
        ];
    }

    public function completed(): static
    {
        return $this->state(fn () => ['status' => 'completed']);
    }

    public function pending(): static
    {
        return $this->state(fn () => ['status' => 'pending']);
    }

    public function forUser(string $userId): static
    {
        return $this->state(fn () => ['user_id' => $userId]);
    }
}
