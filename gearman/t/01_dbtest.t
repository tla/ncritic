#!/usr/bin/env perl -w

use Date::Parse;
use Test::More;
use_ok( 'Text::Tradition::WitnessSet' );

# TODO skip_all statement if sqlite3 isn't in path

my $DBLOC = 't/db/test.db';

# Set up our testing DB
if( -f $DBLOC ) {
	unlink( $DBLOC ) or die "Could not remove old testing DB";
}
system( "sqlite3 $DBLOC < sql/jobtable.sqlite" ) == 0 
	or die "SQLite testing command failed: $!";

my $schema = Text::Tradition::WitnessSet->connect("dbi:SQLite:dbname=$DBLOC");
ok( $schema, "Evidently have DB connection" );

my $new_job = $schema->resultset('WitnessSet')->create({
	witnesses => "In theory this is a JSON string",
	algorithm => 'dekker',
	result_format => 'graphml',
	status => 'new',
	process => '364'
	});
	
ok( $new_job->jobid, "Created a new job" );
sleep( 5 );
$new_job->status('done');
$new_job->result("In theory this is a collation result blob" );
$new_job->update();
is( $new_job->status, "done", "Status was updated" );

my $query_job = $schema->resultset('WitnessSet')->find( $new_job->jobid );
my $created = str2time( $query_job->request_time );
my $updated = str2time( $query_job->update_time );
ok( $updated - $created >= 5, "Timestamps were handled correctly" );

done_testing();
unlink( $DBLOC );
