#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use lib '/Users/tla/Projects/ncritic/cpan/Text-TEI-Collate/lib';

use Encode qw/ encode_utf8 /;
use LWP::UserAgent;

open( FH, $ARGV[0] ) or die "Could not read @ARGV";
binmode( FH, ':encoding(UTF-8)' );
my @lines = <FH>;
close FH;
my $xmlcontent = join( '', @lines );

my $ua = LWP::UserAgent->new();
my $resp = $ua->post( 'http://localhost:3000/msview/xml_to_json',
      'Content-Type' => 'text/xml; charset=utf-8',
      'Content' => encode_utf8( $xmlcontent )
    );
if( $resp->is_success ) {
      say $resp->content;
} else {
      die "Collator returned error " . $resp->code . ": " . $resp->content;
}

