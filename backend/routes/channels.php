<?php

use Illuminate\Support\Facades\Broadcast;

Broadcast::routes(['middleware' => ['auth:api']]);

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

Broadcast::channel('call.{id}', function ($user, $id) {
    // Both caller and receiver will listen to their own user ID channel
    // e.g. caller listens to call.{caller_id}, receiver listens to call.{receiver_id}
    return (int) $user->id === (int) $id;
});

Broadcast::channel('chat.{id}', function ($user, $id) {
    // For prototyping we just return true. Normally you'd check if $user is in the chat participants
    return true;
});
