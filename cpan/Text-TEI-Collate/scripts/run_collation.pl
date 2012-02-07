#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use lib 'lib';
use File::Basename;
use Getopt::Long;
use Text::TEI::Collate;

binmode STDOUT, ':utf8';

my( $debug, $fuzziness, $language, $outformat, $name_sigla, $show_help ) 
	= ( undef, 50, 'Default', 'csv', 0, undef );
GetOptions( 
	    'debug:i' => \$debug,
	    'fuzziness=i' => \$fuzziness,
	    'l|language=s' => \$language,
	    'o|output=s' => \$outformat,
	    'fn|filename_sigla' => \$name_sigla,
	    'h|help' => \$show_help,
    );
## Option checking
if( defined $debug ) {
    # If it's defined but false, no level was passed.  Use default 1.
    $debug = 1 unless $debug;
} else {
    $debug = 0;
}

if( $show_help ) {
	help();
	exit;
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

sub help {
	say STDERR "Usage: run_collation.pl <options> -o <format> text1.txt text2.xml [...]";
	say STDERR "Options include:";
	say STDERR "   d|debug - Turn on debugging output.";
	say STDERR "   f|fuzziness - Set the match fuzziness factor for the collation.";
	say STDERR "   l|language - Name of language module to use.";
	say STDERR "      Defaults to 'Default'; can also be 'Armenian', 'Latin', 'Greek'.";
	say STDERR "   o|output (required) Output format for the results.";
	say STDERR "      Can be one of json, csv, tei, graphml, svg.";
}
