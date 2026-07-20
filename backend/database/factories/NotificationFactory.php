<?php

namespace Database\Factories;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Notification>
 */
class NotificationFactory extends Factory
{
    protected $model = Notification::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'title' => fake()->sentence(3),
            'message' => fake()->paragraph(1),
            'type' => fake()->randomElement(['info', 'warning', 'success', 'project', 'payment']),
            'data' => null,
            'is_read' => fake()->boolean(30),
            'created_at' => fake()->dateTimeBetween('-1 month', 'now'),
        ];
    }

    public function unread(): static
    {
        return $this->state(fn () => ['is_read' => false]);
    }

    public function forUser(string $userId): static
    {
        return $this->state(fn () => ['user_id' => $userId]);
    }
}
