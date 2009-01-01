#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use File::Basename;
use Test::More 'no_plan';
use Text::WagnerFischer::Armenian qw( distance );
use Text::TEI::Collate;
use Words::Armenian;
use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
eval { no warnings; binmode $DB::OUT, ":utf8"; };

# Find the test files.
my $dirname = dirname( $0 );
my $testdir_plain = "$dirname/data/plaintext";
my $testdir_xml = "$dirname/data/xml_plain";
my $testdir_xmlfull = "$dirname/data/xml_word";

# Set the expected values.
my $expected_word_length = 281;
# The XML versions will have four extra columns, for the
# section marker placeholders.
my $xml_word_length = 285;

my $aligner_plain = Text::TEI::Collate->new( 'fuzziness' => 50,
       'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
       'canonizer' => \&Words::Armenian::canonize_word,
    );
opendir( PLAIN, "$testdir_plain" ) or die "Could not find plaintext test files: $@";
my @plain_fn;
while( my $fn = readdir PLAIN ) {
    next unless $fn =~ /\.txt$/;
    push( @plain_fn, "$testdir_plain/$fn" );
}
my @plain_mss = $aligner_plain->align( @plain_fn );
is( scalar @plain_mss, 5, "Returned five objects" );
foreach( @plain_mss ) {
    is( ref $_, 'Text::TEI::Collate::Manuscript', "Object of correct type" );
    is( ref $_->words, 'ARRAY', "Object has words array" );
    is( ref $_->words->[0], 'Text::TEI::Collate::Word', "Words array has words" );
    is( scalar @{$_->words}, $expected_word_length, "Words array for plaintext is correct length" );
}

my $aligner_xml = Text::TEI::Collate->new( 'fuzziness' => 50,
	'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
	'canonizer' => \&Words::Armenian::canonize_word,
	'TEI' => 1,
    );
opendir( XML, "$testdir_xml" ) or die "Could not find XML test files: $@";
my @xml_fn;
while( my $fn = readdir XML ) {
    next unless $fn =~ /\.xml$/;
    push( @xml_fn, "$testdir_xml/$fn" );
}
my @xml_mss = $aligner_xml->align( @xml_fn );
is( scalar @xml_mss, 5, "Returned five objects" );
foreach( @xml_mss ) {
    is( ref $_, 'Text::TEI::Collate::Manuscript', "Object of correct type" );
    is( ref $_->words, 'ARRAY', "Object has words array" );
    is( ref $_->words->[0], 'Text::TEI::Collate::Word', "Words array has words" );
    is( scalar @{$_->words}, $xml_word_length, "Words array for XML is correct length" );
}
# Check for the right number of divisional markers.
my @ph_ind;
foreach my $i ( 0 .. $#{$xml_mss[0]->words} ) {
    my @words = map { $_->words->[$i] } @xml_mss;
    my $found = grep { $_->placeholder } @words;
    push( @ph_ind, $i ) if $found;
}
is( scalar @ph_ind, $xml_word_length - $expected_word_length, "Found correct number of placeholders" );

my $aligner_xmlfull = Text::TEI::Collate->new( 'fuzziness' => 50,
	'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
	'canonizer' => \&Words::Armenian::canonize_word,
	'TEI' => 1,
    );
opendir( XMLFULL, "$testdir_xmlfull" ) or die "Could not find xmlfulltext test files: $@";
my @xmlfull_fn;
while( my $fn = readdir XMLFULL ) {
    next unless $fn =~ /\.xml$/;
    push( @xmlfull_fn, "$testdir_xmlfull/$fn" );
}
my @xmlfull_mss = $aligner_xmlfull->align( @xmlfull_fn );
is( scalar @xmlfull_mss, 5, "Returned five objects" );
foreach( @xmlfull_mss ) {
    is( ref $_, 'Text::TEI::Collate::Manuscript', "Object of correct type" );
    is( ref $_->words, 'ARRAY', "Object has words array" );
    is( ref $_->words->[0], 'Text::TEI::Collate::Word', "Words array has words" );
    is( scalar @{$_->words}, $xml_word_length, "Words array for wrapped XML is correct length" );
}
# Make sure the placeholders are all in the right place.
my @ph_ind_2;
foreach my $i ( 0 .. $#{$xml_mss[0]->words} ) {
    my @words = map { $_->words->[$i] } @xml_mss;
    my $found = grep { $_->placeholder } @words;
    push( @ph_ind_2, $i ) if $found;
}
is( scalar @ph_ind_2, $xml_word_length - $expected_word_length, "Found correct number of placeholders" );
is_deeply( \@ph_ind, \@ph_ind_2, "placeholder indices match" );


# my @results = ( $plain_mss[0]->words, $xmlfull_mss[0]->words );
# # Print the array.
# foreach my $i ( 0 .. 280 ) {
#     my $output_str = join( '| ', map { sprintf( "%-25s", $_->[$i]->printable ) } @results ) . "\n";
#     print $output_str;
# }


