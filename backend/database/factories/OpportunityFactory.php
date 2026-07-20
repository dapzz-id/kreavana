<?php

namespace Database\Factories;

use App\Models\Opportunity;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Opportunity>
 */
class OpportunityFactory extends Factory
{
    protected $model = Opportunity::class;

    public function definition(): array
    {
        return [
            'title' => fake()->sentence(4),
            'description' => fake()->paragraph(2),
            'sub_role_slug' => fake()->randomElement([
                'photographer', 'videographer', 'editor', 'event_organizer',
                'wedding_organizer', 'institution', 'government', 'community',
            ]),
            'type' => fake()->randomElement(['location', 'project']),
            'location' => fake()->city(),
            'address' => fake()->address(),
            'deadline' => fake()->dateTimeBetween('+1 week', '+3 months'),
            'budget_range' => 'Rp ' . number_format(fake()->numberBetween(1000000, 50000000), 0, ',', '.'),
            'status' => fake()->randomElement(['open', 'closed']),
            'posted_by' => User::factory(),
            'created_at' => fake()->dateTimeBetween('-6 months', 'now'),
        ];
    }

    public function open(): static
    {
        return $this->state(fn () => ['status' => 'open']);
    }

    public function closed(): static
    {
        return $this->state(fn () => ['status' => 'closed']);
    }

    public function forUser(string $userId): static
    {
        return $this->state(fn () => ['posted_by' => $userId]);
    }
}
