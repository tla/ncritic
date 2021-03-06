package ncritic;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    ConfigLoader
    Static::Simple
	Session
    Session::Store::DBI
    Session::State::Cookie
/;

extends 'Catalyst';

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in ncritic.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'ncritic',
    encoding => 'UTF-8',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
	default_view => 'TT',
	'View::JSON' => {
		expose_stash => 'result'
	},
	'Plugin::Session' => {
        expires   => 3600,
        dbi_dsn   => 'dbi:SQLite:dbname=db/sessions.db',
        dbi_table => 'sessions'
	},
	'Model::WitnessSet' => {
		connect_info => _witnesses_connectinfo()
	}
);

# Start the application
__PACKAGE__->setup();


sub _witnesses_connectinfo {
	my $fromconfig = eval { require Text::Tradition::WitnessSet::Util; };
	$DB::single = 1;
	my $cinfo;
	if( $fromconfig ) {
		$cinfo = Text::Tradition::WitnessSet::Util::get_db_connectinfo();
	} 
	unless( $cinfo ) {
		$cinfo = { dsn => 'dbi:SQLite:dbname=db/witnesses.db' };
	}
	return $cinfo;
}

=head1 NAME

ncritic - Catalyst based application

=head1 SYNOPSIS

    script/ncritic_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<ncritic::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
