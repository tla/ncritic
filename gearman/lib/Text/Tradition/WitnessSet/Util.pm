package Text::Tradition::WitnessSet::Util;

use strict;
use warnings;
use feature qw/ say unicode_strings /;
use DBI;
use Encode qw/ decode_utf8 /;
use Exporter qw/ import /;
use JSON;

use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw/ get_collatex_path get_db_connectinfo get_dbhandle get_gearman_server /;

my %VARS;
sub _read_vars {
	return if keys %VARS;
	%VARS = (
		DBTYPE => 'SQLite',
		DBHOST => undef,
		DBPORT => undef,
		DBNAME => '/tmp/collations.db',
		DSN => undef,
		DBUSER => undef,
		DBPASS => undef,
		GEARMAN_SERVER => '127.0.0.1:4730',
		COLLATEXPATH => undef,
	);

	my $config_file = "/etc/collation.conf";
	if( -f $config_file ) {
		# Read the variables in from here.
		open( GCCONF, $config_file ) 
			or die "Could not open configuration file $config_file";
		while(<GCCONF>) {
			chomp;
			s/^\s+//;
			my( $name, $val ) = split( /\s*\=\s*/, $_ );
			if( exists $VARS{$name} ) {
				$VARS{$name} = $val;
			}
		}
		close GCCONF;
		return keys %VARS;
	} else {
		return 0;
	}
}

sub _get_dsn {
	unless( $VARS{DSN} ) {
		$VARS{DSN} = sprintf( 'dbi:%s:dbname=%s',
			$VARS{DBTYPE}, $VARS{DBNAME} );
		$VARS{DSN} .= sprintf( ';host=%s', $VARS{DBHOST} ) if $VARS{DBHOST};
		$VARS{DSN} .= sprintf( ';port=%s', $VARS{DBPORT} ) if $VARS{DBPORT};
	}
	return $VARS{DSN};
}

sub get_db_connectinfo {
	return unless _read_vars();
	my $info = { dsn => _get_dsn() };
	if( $VARS{DBUSER} ) {
		$info->{user} = $VARS{DBUSER};
	}
	if( $VARS{DBPASS} ) {
		$info->{password} = $VARS{DBPASS};
	}
	return $info;
}

sub get_dbhandle {
	return unless _read_vars();
	my @dbargs = ( _get_dsn() );
	push( @dbargs, $VARS{DBUSER} ) if $VARS{DBUSER};
	push( @dbargs, $VARS{DBPASS} ) if $VARS{DBPASS};

	my $dbh = DBI->connect( @dbargs );
	return $dbh;
}

sub get_collatex_path {
	return unless _read_vars();
	return $VARS{COLLATEXPATH};
}

sub get_gearman_server {
	return unless _read_vars();
	return $VARS{GEARMAN_SERVER};
}

1;
