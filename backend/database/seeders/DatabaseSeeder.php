<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            UserSeeder::class,
            RemainingTablesSeeder::class,
        ]);

        // 1. Create main user
        $me = User::factory()->create([
            'name' => 'Anda',
            'email' => 'anda@example.com',
        ]);

        // 2. Create other users
        $user1 = User::factory()->create(['name' => 'Pengguna 1', 'email' => 'user1@example.com']);
        $user2 = User::factory()->create(['name' => 'Pengguna 2', 'email' => 'user2@example.com']);
        $user3 = User::factory()->create(['name' => 'Budi', 'email' => 'budi@example.com']);

        // 3. Create a personal chat
        $chat1 = \App\Models\Chat::create(['type' => 'personal']);
        \App\Models\ChatParticipant::create(['chat_id' => $chat1->id, 'user_id' => $me->id]);
        \App\Models\ChatParticipant::create(['chat_id' => $chat1->id, 'user_id' => $user1->id]);
        
        \App\Models\Message::create(['chat_id' => $chat1->id, 'user_id' => $user1->id, 'message' => 'Halo, ada yang bisa dibantu?']);

        // 4. Create a group chat
        $groupChat = \App\Models\Chat::create(['type' => 'group', 'name' => 'Tim Proyek Alpha', 'only_admin_can_add' => true]);
        \App\Models\ChatParticipant::create(['chat_id' => $groupChat->id, 'user_id' => $me->id, 'is_admin' => true]);
        \App\Models\ChatParticipant::create(['chat_id' => $groupChat->id, 'user_id' => $user2->id, 'is_admin' => false]);
        \App\Models\ChatParticipant::create(['chat_id' => $groupChat->id, 'user_id' => $user3->id, 'is_admin' => false]);

        \App\Models\Message::create(['chat_id' => $groupChat->id, 'user_id' => $user2->id, 'message' => 'Tolong review pekerjaan saya.']);
    }
}
