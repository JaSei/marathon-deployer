#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;
use Mock::Quick;
use FindBin qw($Bin);

use lib "$Bin/../../lib";

use_ok('App::MarathonDeployer');

throws_ok {
    App::MarathonDeployer->new();
}
qr/marathon_url/i, 'marathon_url check';

throws_ok {
    App::MarathonDeployer->new(
        marathon_url       => 'test',
        marathon_json_file => 'nonexistent_marathon.json',
    );
}
qr/The file 'nonexistent_marathon.json'/, 'marathon_json_file check';

subtest 'invalid json' => sub {
    my $json_file = Path::Tiny->tempfile();

    $json_file->append('xyz');

    throws_ok {
        my $deployer = App::MarathonDeployer->new(
            marathon_url       => 'test',
            marathon_json_file => $json_file->stringify(),
            cpu_profile        => 'normal',
        )->run();
    }
    qr/Malformed JSON/, 'invalid json';

    done_testing(1);
};

subtest 'run' => sub {
    my $class_res = qclass(
        -with_new => 1,
        code      => 200,
        body      => '[]',
    );

    my $class_req = qclass(
        -with_new => 1,
        res       => sub {
            $class_res->package->new();
        }
    );

    my $class_ua = qclass(
        -with_new => 1,
        put       => sub {
            my (undef, $url, $type, $marathon_json) = @_;

            is($url, 'test/v2/apps/app_id', 'check url and set marathon_application_name');

            is($marathon_json->{instances}, 2, 'check marathon_instances');

            is($marathon_json->{container}{docker}{image}, 'other_image', 'check docker_image_name');

            $class_req->package->new();
        },
        get => sub { $class_req->package->new() },
    );

    my $deployer = App::MarathonDeployer->new(
        marathon_url       => 'test',
        marathon_json_file => $0,
        marathon_json      => {
            id        => 'some_app',
            instances => 1,
            cpus      => 1,
            container => {
                docker => {
                    image => 'some_imagae',
                }
            }
        },
        ua                        => $class_ua->package->new(),
        marathon_application_name => 'app_id',
        marathon_instances        => 2,
        docker_image_name         => 'other_image',
        cpu_profile               => 'normal',
    );

    $deployer->run();
};

subtest 'compute_cpus' => sub {
    my $class_res = qclass(
        -with_new       => 1,
        is_success      => 1,
        json            => {
            slaves => [
                { resources => {cpus => 1, mem => 40} },
                { resources => {cpus => 4, mem => 40} },
                { resources => {cpus => 5, mem => 20} },
            ]
        }
    );

    my $class_req = qclass(
        -with_new => 1,
        res       => sub { $class_res->package->new() },
    );

    my $class_ua = qclass(
        -with_new => 1,
        get       => sub { $class_req->package->new() },
    );

    my $deployer = App::MarathonDeployer->new(
        marathon_url       => 'marathon',
        marathon_json_file => $0,
        marathon_json      => {
            instances => 1,
            mem       => 20,
            container => {
                docker => {
                }
            }
        },
        ua                        => $class_ua->package->new(),
        marathon_application_name => 'app_id',
        docker_image_name         => 'some_image',
        cpu_profile               => 'normal',
    );

    is($deployer->compute_cpus(), 2, 'cpus computed correctly');
};
