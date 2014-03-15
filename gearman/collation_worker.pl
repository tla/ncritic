#!/usr/bin/env perl

use strict;
use warnings;
use feature qw/ say unicode_strings /;
use DBI;
use Encode qw/ decode_utf8 /;
use Gearman::Worker;
use IPC::Run qw/ run /;
use JSON;
use Text::TEI::Collate;
use TryCatch;

# Database record will be:
# - jobid
# - witnesses
# - algorithm
# - result_format
# - status
# - process
# - result

my %VARS = (
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

if( -f "/etc/collation.conf" ) {
	# Read the variables in from here.
	open( GCCONF, "/etc/collation.conf" ) 
		or die "Could not open configuration file /etc/collation.conf";
	while(<GCCONF>) {
		chomp;
		s/^\s+//;
		my( $name, $val ) = split( /\s*\=\s*/, $_ );
		if( exists $VARS{$name} ) {
			$VARS{$name} = $val;
		}
	}
	close GCCONF;
}
unless( $VARS{DSN} ) {
	$VARS{DSN} = sprintf( 'dbi:%s:dbname=%s',
		$VARS{DBTYPE}, $VARS{DBNAME} );
	$VARS{DSN} .= sprintf( ';host=%s', $VARS{DBHOST} ) if $VARS{DBHOST};
	$VARS{DSN} .= sprintf( ';port=%s', $VARS{DBPORT} ) if $VARS{DBPORT};
}

my @dbargs = ( $VARS{DSN} );
push( @dbargs, $VARS{DBUSER} ) if $VARS{DBUSER};
push( @dbargs, $VARS{DBPASS} ) if $VARS{DBPASS};

my $dbh = DBI->connect( @dbargs );

my $worker = Gearman::Worker->new();
$worker->job_servers( $VARS{GEARMAN_SERVER} );
$worker->register_function( run_collation => \&run_collation );
$worker->work while 1;

sub run_collation {
    my $job = shift;   # This is the job ID. Look it up in the DB
    my $sth = $dbh->prepare( 'SELECT * FROM collations WHERE jobid = ?' );
    $sth->execute( $job );
    while( my $data = $sth->fetchrow_hashref ) {
    	if( $data->{status} =~ /^(completed|dead|failed)$/ ) {
    		return; # Nothing to do.
    	} 
		if( $data->{status} eq 'running' ) {
			# Check whether the process is still running. If so, return;
			# if not, mark it as failed and return.
			unless( check_existing( $data ) ) {
				my $update = $dbh->prepare( 'UPDATE collations SET status = ? WHERE jobid = ?' );
				$update->execute( 'dead', $job );
			}
			return;
		} else {
			# Get to work. First update the job status
			my $update = $dbh->prepare( 'UPDATE collations SET status = ?, process = ? WHERE jobid = ?' );
			$update->execute( 'running', $$, $job );
			# Then dispatch the data to the appropriate collation routine
			my $result;
			my $input = $data->{witnesses};
			if( $data->{algorithm} eq 'diff' ) {
				# Use the Perl collator
				my $collator = Text::TEI::Collate->new();
				my @mss = $collator->read_source( $input );
				# TODO error handling!
				$collator->align( @mss );
				my $outsub = 'to_' . $data->{result_format};
				$result = $collator->$outsub( @mss );
			} else {
				# Use CollateX
				$ENV{'PATH'} = join( ':', '/bin', '/usr/bin', '/usr/local/bin',
					$VARS{COLLATEXPATH} );
				my @cmd = qw/ collatex -t /;
				push( @cmd, '-a', $data->{algorithm} );
				push( @cmd, '-f', $data->{result_format} );
				my $err;
				run( \@cmd, \$input, \$result, \$err );
				# TODO error checking
			}
			my $final = $dbh->prepare( 'UPDATE collations SET status = ?, result = ? WHERE jobid = ?' );
			$final->execute( 'complete', $result, $job );
		}
	}
}


sub check_existing {
	my $data = shift;
	return( -d "/proc/" . $data->{process} );
}