#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
$| = 1;



# =begin testing
{
use Test::More::UTF8;
use Text::TEI::Collate::Lang::Greek;

my $comp = \&Text::TEI::Collate::Lang::Greek::comparator;
is( $comp->( 'abcd' ), 'abcd', "Got correct no-op comparison string" );
is( $comp->( "ἔστιν" ), "εστιν", "Got correct unaccented comparison string");
}




1;
