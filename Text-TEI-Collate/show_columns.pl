#!/usr/bin/perl -w

use strict;
use lib 'lib';
use Data::Dumper;
use Text::WagnerFischer::Armenian qw( distance );
use Text::TEI::Collate;
use Words::Armenian;
use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
eval { no warnings; binmode $DB::OUT, ":utf8"; };

# Control what we print.
my $col_width = 25;  # if we aren't printing CSV
my $CSV = 1;         # use CSV format

my $type = shift @ARGV;
unless( $type eq 'txt' ) {
    unshift( @ARGV, $type );
    $type = 'xml';
}

my( @files ) = @ARGV;

# and how fuzzy a match we can tolerate.
my $fuzziness = "50";  # this is n%

my $aligner = Text::TEI::Collate->new( 'fuzziness' => $fuzziness,
				       'debug' => 2,
				       'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
				       # 'accents' => [ "\x{55b}" ],
				       'canonizer' => \&Words::Armenian::canonize_word,
				       'TEI' => ( $type eq 'xml' ),
    );


my @results = $aligner->align( @files );

my $length = 0;
my $arr_idx = 0;
foreach( map { $_->words } @results ) {
    $length = scalar( @$_ ) unless $length;
    if( scalar @$_ != $length ) {
        warn "Array $arr_idx is " . @$_ . " instead of $length items long\n";
	$length = scalar @$_ if scalar @$_ < $length;
    }
    $arr_idx++
}

# Print the array.
print_fnames() if $CSV;
foreach my $i ( 0 .. $length-1 ) {
    my $output_str;
    if( $CSV ) {
	$output_str = join( ',', map { '"' . $_->words->[$i]->printable . '"' } @results ) . "\n";
    } else {
	my $format = '%-' . $col_width . "s";
	$output_str = join( '| ', map { sprintf( $format, $_->words->[$i]->printable ) } @results ) . "\n";
    }
    print_fnames( $i ) unless ( $CSV || $i % 100 );
    print $output_str;
}


print "Done.\n";


sub open_file {
    my( $file ) = shift;
    local *FH;
    open( FH, "<:utf8", $file ) or die "Could not open file $file\n";
    return *FH;
}

sub print_fnames {
    print "\n\tLine $_[0]\n" if $_[0];
    if( $CSV ) {
	print join( ',', @files ) . "\n";
    } else {
	print join( '| ', map { sprintf( "%-25s", $_ ) } @files ) . "\n";
    }
}


