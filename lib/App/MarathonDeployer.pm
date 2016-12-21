package App::MarathonDeployer;
use 5.010;
use strict;
use warnings;
use List::Util qw(sum);

our $VERSION = "0.1.0";

use feature 'say';
use Data::Dumper;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Path::Tiny;
use URI;
use URI::Escape qw(uri_escape);
use Class::Tiny
qw(
    marathon_url
    cpu_profile
    docker_image_name
    marathon_application_name
    marathon_instances
    marathon_json_file
    deployment_verification_timeout
),
{
    marathon_json => sub {
        my ($self) = @_;

        return decode_json(path($self->marathon_json_file)->slurp);
    },
    ua => sub {
        return Mojo::UserAgent->new();
    },
    marathon_apps_url => sub {
        my ($self) = @_;

        return sprintf '%s/v2/apps', $self->marathon_url;
    },
    app_url => sub {
        my ($self) = @_;

        return URI->new($self->marathon_apps_url . "/" . uri_escape($self->marathon_json->{id}))
          ->canonical->as_string();
    }
};

sub BUILD {
    my ($self) = @_;

    if (!$self->marathon_url) {
        die 'Environment variable MARATHON_URL not set. Exiting...';
    }

    if (!-f $self->marathon_json_file) {
        die "The file '".$self->marathon_json_file."' does not exist.";
    }

    if (!-f $self->marathon_json_file) {
        die "The file '".$self->marathon_json_file."' does not exist.";
    }

    if ($self->marathon_application_name) {
        $self->marathon_json->{id} = $self->marathon_application_name;
    }

    if ($self->docker_image_name) {
        $self->marathon_json->{container}{docker}{image} = $self->docker_image_name;
    }

    if (defined $self->marathon_instances) {
        die 'Environment variable MARATHON_INSTANCES must be non-negative integer or undefined, '
            . "'".$self->marathon_instances."' given. Exiting..."
            if ! is_nonnegative_integer($self->marathon_instances);

        $self->marathon_json->{instances} = int($self->marathon_instances);
    }

    die 'CPU_PROFILE ' . $self->cpu_profile . ' is not one of low|normal|high'
        if !grep {$self->cpu_profile eq $_} qw(low normal high);
    $self->marathon_json->{cpus} //= $self->compute_cpus();
}

sub compute_cpus {
    my ($self) = @_;

    my $profile_coef =
        {low => 0.3, normal => 1, high => 3}->{$self->cpu_profile};

    my $resources_ratio = $self->compute_mesos_resources_ratio();

    return $profile_coef * $resources_ratio * $self->marathon_json->{mem}
}

sub compute_mesos_resources_ratio {
    my ($self) = @_;

    my $mesos_url = $self->get_mesos_url_from_marathon();
    my $url = $mesos_url . 'state.json';
    my $res = $self->ua->get($url)->res;
    die "Request to mesos $url failed: " . $res->to_string
        if !$res->is_status_class(200);

    my $cpus = sum( map {$_->{resources}{cpus} } @{ $res->json->{slaves} } );
    my $mem =  sum( map {$_->{resources}{mem}  } @{ $res->json->{slaves} } );

    return $cpus / $mem;
}

sub get_mesos_url_from_marathon {
    my ($self) = @_;

    my $url = $self->marathon_url . '/v2/info';
    my $res = $self->ua->get($url)->res;
    die "Request to marathon $url failed: " . $res->to_string
        if !$res->is_status_class(200);

    my $mesos_url = $res->json->{marathon_config}{mesos_leader_ui_url};
    print STDERR "$mesos_url\n";

    return $mesos_url
}

sub run {
    my ($self) = @_;

    # print STDERR "App URL: " . $self->app_url . "\n";
    my $res = $self->ua->put($self->app_url => json => $self->marathon_json)->res();

    if ($res->code != 200 && $res->code != 201) {
        die $res->to_string();
    }

    $self->verify_deployment_finished();
}

sub verify_deployment_finished {
    my ($self) = @_;

    my $deployment_url = $self->marathon_url. '/v2/deployments';
    my $application_id = $self->marathon_json->{id};
    my $timeout = $self->deployment_verification_timeout;

    my $number_of_deployments = $self->number_of_deployments($deployment_url, $application_id);
    my $deployment_check_wait_time = 5;
    while ($number_of_deployments > 0 && $timeout > 0) {
        print STDERR "Waiting for $number_of_deployments deployment(s) to finish..." . "\n";
        sleep($deployment_check_wait_time);

        $timeout -= $deployment_check_wait_time;
        $number_of_deployments = $self->number_of_deployments($deployment_url, $application_id);
    }

    if ($number_of_deployments > 0) {
        die "Deployment did not finish successfully. " .
            "There are still $number_of_deployments ongoing deployment(s). " .
            "You have to solve this manually in Marathon.";
    }
    else {
        print STDERR "Deployment was successful.\n";
    }
}

sub is_nonnegative_integer {
    local $_ = shift;
    return /\A\+?\d+\z/
}

sub number_of_deployments {
    my ($self, $deployment_url, $application_id) = @_;

    my $res           = $self->ua->get($deployment_url)->res();
    my $parsed_result = decode_json($res->body);

    my $active_deployments = 0;
    foreach my $deployment (@$parsed_result) {
        my $applications_being_deployed = $deployment->{affectedApps};
        if (grep { $_ eq "/$application_id" } @$applications_being_deployed) {
            $active_deployments++;
        }
    }

    return $active_deployments;
}

1;
__END__

=encoding utf-8

=head1 NAME

App::MarathonDeployer - deployment to mesos-marathon

=head1 SYNOPSIS


=head1 DESCRIPTION

A simple script for deploying docker images to marathon-based cloud.

    docker run \
        -v /path/to/your/marathon.json:/marathon.json \
        -e MARATHON_URL=<your_marathon_url> avastsoftware/marathon-deployer

It will simply do the POST or PUT request to deploy your app.

Optionally you can also provide these environment variables:
- MARATHON_JSON - name of your JSON file (default is marathon.json)
- MARATHON_APPLICATION_NAME - name of the application (id), this will be replaced in marathon json before submitting it
- MARATHON_INSTANCES - number of instances, this will be replaced in marathon json before submitting it
- DOCKER_IMAGE_NAME - name of the docker image, this will be replaced in marathon json before submitting it
- CPU_PROFILE - one of low|normal|high. If cpus is not set in marathon.json, it gets computed from total cloud's CPU/memory ratio. If you choose normal profile, the cpus is set to mem * ratio, low = 0.3 * normal, high = 3 * normal.

What it does for you:
- construct the URL to deploy
- do PUT request to marathon with provided JSON file
- parse response and set the return code accordingly

=head1 LICENSE

Copyright (C) Avast Software

=head1 AUTHOR

Miroslav Tynovsky E<lt>tynovsky@avast.comE<gt>

=cut

