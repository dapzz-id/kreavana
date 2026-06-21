@extends('layouts.app')
@section('title', 'Profil - KREAVANA')

@section('content')
@php
    // ProfileController@show returns this view — redirect logic to edit
    return redirect()->route('profile');
@endphp
@endsection
