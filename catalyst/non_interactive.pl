#!/opt/local/bin/perl

use strict;
use feature qw( say );
use LWP::UserAgent;

my @lines;
while(<>) {
    push( @lines, $_ );
}
my $xmlstr = join( '', @lines );

my $ua = LWP::UserAgent->new();
#my $response = $ua->post('http://www.eccentricity.org/teitokenizer/form_tokenize',
my $response = $ua->post('http://localhost:3000/tokenizetei/run_tokenize',
			 { 'xmltext' => $xmlstr, }
    );

if( $response->is_success ) {
    say $response->headers->as_string;
    say $response->content;
}

