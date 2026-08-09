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
            OpportunityLocationSeeder::class,
            DashboardMockSeeder::class,
        ]);

        // 1. Create main user
        $me = User::updateOrCreate(
            ['email' => 'anda@example.com'],
            ['name' => 'Anda', 'username' => 'anda', 'password' => bcrypt('password')]
        );

        // 2. Create other users
        $user1 = User::updateOrCreate(['email' => 'user1@example.com'], ['name' => 'Pengguna 1', 'username' => 'pengguna1', 'password' => bcrypt('password')]);
        $user2 = User::updateOrCreate(['email' => 'user2@example.com'], ['name' => 'Pengguna 2', 'username' => 'pengguna2', 'password' => bcrypt('password')]);
        $user3 = User::updateOrCreate(['email' => 'budi@example.com'], ['name' => 'Budi', 'username' => 'budi', 'password' => bcrypt('password')]);

        // 3. Create a personal chat
        $chat1 = \App\Models\Chat::firstOrCreate(['type' => 'personal']);
        \App\Models\ChatParticipant::firstOrCreate(['chat_id' => $chat1->id, 'user_id' => $me->id]);
        \App\Models\ChatParticipant::firstOrCreate(['chat_id' => $chat1->id, 'user_id' => $user1->id]);
        
        \App\Models\Message::firstOrCreate(['chat_id' => $chat1->id, 'user_id' => $user1->id, 'message' => 'Halo, ada yang bisa dibantu?']);

        // 4. Create a group chat
        $groupChat = \App\Models\Chat::firstOrCreate(['type' => 'group', 'name' => 'Tim Proyek Alpha', 'only_admin_can_add' => true]);
        \App\Models\ChatParticipant::firstOrCreate(['chat_id' => $groupChat->id, 'user_id' => $me->id], ['is_admin' => true]);
        \App\Models\ChatParticipant::firstOrCreate(['chat_id' => $groupChat->id, 'user_id' => $user2->id], ['is_admin' => false]);
        \App\Models\ChatParticipant::firstOrCreate(['chat_id' => $groupChat->id, 'user_id' => $user3->id], ['is_admin' => false]);

        \App\Models\Message::create(['chat_id' => $groupChat->id, 'user_id' => $user2->id, 'message' => 'Tolong review pekerjaan saya.']);
    }
}
