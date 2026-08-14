<?php

use Illuminate\Support\Facades\Broadcast;

Broadcast::routes(['middleware' => ['auth:api']]);

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return $user->id === $id;
});

Broadcast::channel('call.{id}', function ($user, $id) {
    // Both caller and receiver will listen to their own user ID channel
    return $user->id === $id;
});

Broadcast::channel('chat.{id}', function ($user, $id) {
    // For prototyping we just return true. Normally you'd check if $user is in the chat participants
    return true;
});
