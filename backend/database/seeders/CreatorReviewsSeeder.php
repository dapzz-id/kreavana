<?php

namespace Database\Seeders;

use App\Models\Opportunity;
use App\Models\OpportunityReview;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\MarketplaceReview;
use Illuminate\Database\Seeder;
use Faker\Factory as Faker;

class CreatorReviewsSeeder extends Seeder
{
    public function run(): void
    {
        $faker = Faker::create('id_ID');

        $creators = User::whereNotNull('sub_role')
            ->whereIn('role', ['creator', 'admin'])
            ->get()
            ->shuffle();

        $clients = User::where('role', 'user')
            ->orWhereNull('role')
            ->get()
            ->shuffle();

        $sampleComments = [
            'Keren banget hasilnya, tepat waktu dan sesuai request!',
            'Profesional sekali, komunikasi lancar. Recommended!',
            'Hasil foto/video super detail, pengerjaan cepat.',
            'Sangat memuaskan. Harga sebanding dengan kualitas.',
            'Pengerjaan di atas ekspektasi. Akan pakai lagi nanti.',
            'Proses onboarding gampang, revisi juga cepat ditanggapi.',
            'Kualitas premium, harga bersaing. 5 star!',
            'Sudah 3x pakai jasanya, tidak pernah kecewa.',
            'Team responsif dan friendly, cocok buat project wedding.',
            'Karya detail, warna bagus, edit smooth. Top!',
        ];

        foreach ($creators as $creator) {
            $totalReviews = $faker->numberBetween(4, 22);
            $opportunities = Opportunity::where('posted_by', '!=', $creator->id)
                ->inRandomOrder()
                ->limit((int) ceil($totalReviews * 0.6))
                ->get();

            foreach ($opportunities as $opp) {
                $reviewer = $clients->isNotEmpty()
                    ? ($clients->random() ?? $creator)
                    : $creator;

                if ($reviewer->id === $creator->id) {
                    continue;
                }

                $ratingRand = $faker->randomFloat(1, 3.8, 5.0);
                $rating = min(5.0, round($ratingRand, 2));
                $onTime = $rating >= 4.2 ? true : ($faker->boolean(75) ? true : false);

                try {
                    OpportunityReview::create([
                        'opportunity_id' => $opp->id,
                        'reviewer_id'    => $reviewer->id,
                        'creator_id'     => $creator->id,
                        'rating'         => $rating,
                        'is_on_time'     => $onTime,
                        'delivery_days'  => $faker->numberBetween(1, 14),
                        'comment'        => $faker->optional(0.85)->randomElement($sampleComments),
                        'created_at'     => $faker->dateTimeBetween('-6 months', '-3 days'),
                    ]);
                } catch (\Throwable $e) {
                }
            }

            $mpItems = MarketplaceItem::where('user_id', '!=', $creator->id)
                ->inRandomOrder()
                ->limit((int) ceil($totalReviews * 0.4))
                ->get();

            foreach ($mpItems as $item) {
                $seller = User::find($item->user_id);
                if (! $seller) {
                    continue;
                }
                $reviewer = $clients->isNotEmpty() ? $clients->random() : $creator;
                if ($reviewer->id === $seller->id) {
                    continue;
                }
                try {
                    MarketplaceReview::create([
                        'marketplace_item_id' => $item->id,
                        'user_id'             => $reviewer->id,
                        'rating'              => $faker->numberBetween(4, 5),
                        'comment'             => $faker->optional(0.80)->randomElement($sampleComments),
                        'created_at'          => $faker->dateTimeBetween('-6 months', '-3 days'),
                    ]);
                } catch (\Throwable $e) {
                }
            }
        }
    }
}
