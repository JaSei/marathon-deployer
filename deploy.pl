#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Path::Tiny;

my $marathon_url = $ENV{MARATHON_URL}
    or die 'Environment variable MARATHON_URL not set. Exiting...';

my $marathon_apps_url = "$marathon_url/apps";

my $marathon_json_file = $ENV{MARATHON_JSON} || 'marathon.json';
my $marathon_json = decode_json(path($marathon_json_file)->slurp);
my $app_url = "$marathon_apps_url/$marathon_json->{id}";

if ($ENV{DOCKER_IMAGE_NAME}) {
    $marathon_json->{container}{docker}{image} = $ENV{DOCKER_IMAGE_NAME};
}

my $ua = Mojo::UserAgent->new;

my $app_exists = $ua->get($app_url)->res->json->{message} !~ /not exist$/;

if ($app_exists) {
    $ua->put($app_url => json => $marathon_json);
}
else {
    $ua->post($marathon_apps_url => json => $marathon_json);
}

