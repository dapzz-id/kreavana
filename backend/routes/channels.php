<?php

use Illuminate\Support\Facades\Broadcast;

Broadcast::routes(['middleware' => ['auth:api']]);
Broadcast::routes(['prefix' => 'api', 'middleware' => ['auth:api']]);

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (string) $user->id === (string) $id;
});

Broadcast::channel('user.{id}', function ($user, $id) {
    return (string) $user->id === (string) $id;
});

Broadcast::channel('call.{id}', function ($user, $id) {
    // Both caller and receiver will listen to their own user ID channel
    return (string) $user->id === (string) $id;
});

Broadcast::channel('chat.{id}', function ($user, $id) {
    // For prototyping we just return true. Normally you'd check if $user is in the chat participants
    return true;
});
