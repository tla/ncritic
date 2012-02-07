#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';
use File::Basename;
use Getopt::Long;
use Text::TEI::Collate;

binmode STDOUT, ':utf8';

my( $debug, $fuzziness, $language, $outformat, $name_sigla ) 
	= ( undef, 50, 'Default', 'csv', 0 );
GetOptions( 
	    'debug:i' => \$debug,
	    'fuzziness=i' => \$fuzziness,
	    'l|language=s' => \$language,
	    'o|output=s' => \$outformat,
	    'fn|filename_sigla' => \$name_sigla
    );
## Option checking
if( defined $debug ) {
    # If it's defined but false, no level was passed.  Use default 1.
    $debug = 1 unless $debug;
} else {
    $debug = 0;
}

my $aligner = Text::TEI::Collate->new( 
	'language' => $language,
	'fuzziness' => $fuzziness,
	'debug' => $debug,
	);

# Read the sources	
my @mss;
foreach my $source ( @ARGV ) {
	my %options;
	if( $name_sigla ) {
		my $sigil = fileparse( $source, qr/\.[^.]*$/ );
		$sigil =~ s/\s+//g;
		$sigil =~ s/\.txt//;
		$options{'sigil'} = $sigil;
	}
	push( @mss, $aligner->read_source( $source, %options ) );
}

# Do the collation
$aligner->align( @mss );

# Spit out the result
my $sub = 'to_' . $outformat;

print $aligner->$sub( @mss );
