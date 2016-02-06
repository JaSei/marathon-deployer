package App::MarathonDeployer;
use 5.010;
use strict;
use warnings;

our $VERSION = "0.1.0";

use feature 'say';
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Path::Tiny;
use URI;
use URI::Escape qw(uri_escape);
use Class::Tiny 
qw(
    marathon_url
    docker_image_name
    marathon_application_name
    marathon_instances
    marathon_json_file
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
}

sub run {
    my ($self) = @_;

    my $res = $self->ua->put($self->app_url => json => $self->marathon_json)->res();

    if ($res->code != 200 && $res->code != 201) {
        die $res->to_string();
    }

    my $deployment_url = "$self->marathon_url/v2/deployments";
    my $application_id = $self->marathon_json->{id};
    my $deployment_verification_timeout = $ENV{MARATHON_DEPLOY_TIMEOUT_SECONDS} || 120;

    my $number_of_deployments = number_of_deployments($self->ua, $deployment_url, $application_id);
    my $deployment_check_wait_time = 5;
    while ($number_of_deployments > 0 && $deployment_verification_timeout > 0) {
        print "Waiting for $number_of_deployments deployment(s) to finish..." . "\n";
        sleep($deployment_check_wait_time);

        $deployment_verification_timeout -= $deployment_check_wait_time;
        $number_of_deployments = number_of_deployments($self->ua, $deployment_url, $application_id);
    }

    if ($number_of_deployments > 0) {
        die "Deployment did not finish successfully. " .
            "There are still $number_of_deployments ongoing deployment(s). " .
            "You have to solve this manually in Marathon.";
    }
    else {
        print "Deployment was successful.";
    }
}

sub is_nonnegative_integer {
    local $_ = shift;
    return /\A\+?\d+\z/
}

sub number_of_deployments {
    my ($ua, $deployment_url, $application_id) = @_;
    my $res           = $ua->get($deployment_url)->res();
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

What it does for you:
- construct the URL to deploy
- do PUT request to marathon with provided JSON file
- parse response and set the return code accordingly

=head1 LICENSE

Copyright (C) Avast Software

=head1 AUTHOR

Miroslav Tynovsky E<lt>tynovsky@avast.comE<gt>

=cut

