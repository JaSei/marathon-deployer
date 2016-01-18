#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Path::Tiny;
use URI;
use URI::Escape qw(uri_escape);

my $marathon_url = $ENV{MARATHON_URL}
    or die 'Environment variable MARATHON_URL not set. Exiting...';

my $marathon_apps_url = "$marathon_url/apps";

my $marathon_json_file = $ENV{MARATHON_JSON} || 'marathon.json';
die "The file $marathon_json_file does not exist." unless -e $marathon_json_file;

my $marathon_json = decode_json(path($marathon_json_file)->slurp);
my $app_url = URI->new("$marathon_apps_url/".uri_escape($marathon_json->{id}))->canonical->as_string();

if ($ENV{DOCKER_IMAGE_NAME}) {
    $marathon_json->{container}{docker}{image} = $ENV{DOCKER_IMAGE_NAME};
}

if (defined $ENV{MARATHON_INSTANCES}) {
    die 'Environment variable MARATHON_INSTANCES must be non-negative integer or undefined, '
        . "'$ENV{MARATHON_INSTANCES}' given. Exiting..."
        if ! is_nonnegative_integer($ENV{MARATHON_INSTANCES});
    $marathon_json->{instances} = int($ENV{MARATHON_INSTANCES});
}

my $ua = Mojo::UserAgent->new;

my $res = $ua->put($app_url => json => $marathon_json)->res();

if ($res->code != 200 && $res->code != 201) {
    die $res->to_string();
}


sub is_nonnegative_integer {
    local $_ = shift;
    return /\A\+?\d+\z/
}
