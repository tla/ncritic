#!/usr/bin/perl -w

use strict;
use File::Basename;
use IO::File;
use Test::More 'no_plan';
use Text::TEI::Collate::Manuscript;
use XML::LibXML;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
eval { no warnings; binmode $DB::OUT, ":utf8"; };

# Find the test files.
my $dirname = dirname( $0 );
my $testdir_plain = "$dirname/data/plaintext";
my $testdir_xml = "$dirname/data/xml_plain";
my $testdir_xmlfull = "$dirname/data/xml_word";

# Open the plaintext files and try to make a manuscript object from them.
my %sigla = ();
my @wordcount = ( 181, 183, 178, 182, 263 );
my @ph_count = ( 2, 3, 2, 2, 2 );
my %xml_wordcount;
my @json;  # Will eventually contain one JSON 'witnesses' object for 
           # each group of texts.
opendir( PLAIN, $testdir_plain ) or die "Could not open plaintext file dir: $@";
my $idx = 0;
my @text;  # Save the plaintext forms and compare them.
push( @json, { 'witnesses' => [] } );  # element 0
while( my $fn = readdir( PLAIN ) ) {
	next if $fn =~ /^\./;
	my $fh = new IO::File;
	$fh->open( "$testdir_plain/$fn", "<:utf8" );
 	ok( defined $fh, "opened file $fn" );
 	my $lines = join( '', <$fh> );
	$fh->close;
	my @linewords = split( /\s+/, $lines );
	push( @text, join( ' ', @linewords) );
 	my $ms_obj = Text::TEI::Collate::Manuscript->new( 
		'identifier' => $fn,
		'source' => $lines,
		'sourcetype' => 'plaintext',
		);
	is( ref $ms_obj, 'Text::TEI::Collate::Manuscript', "created manuscript object" );
 	is( $ms_obj->identifier(), $fn, "has the right identifier" );
	ok( $ms_obj->sigil(), "sigil was auto-assigned as " . $ms_obj->sigil() );
	ok( !defined( $sigla{$ms_obj->sigil()} ), "sigil not already in use" );
	$sigla{$ms_obj->sigil()} = $fn;
	# Do we have words?
	is( scalar @{$ms_obj->words}, $wordcount[$idx], "manuscript has correct number of words" );
	# Are they the right words?
	my $t = $text[$idx];
	is( join( ' ', map { $_->original_form } @{$ms_obj->words} ), $t, "ms original words match words in file" );
	$t =~ s/[[:punct:]]//g;
	is( join( ' ', map { $_->word } @{$ms_obj->words} ), $t, "ms default words match words in file" );
	push( @{$json[0]->{'witnesses'}}, $ms_obj->tokenize_as_json );
	$idx++;
}
close PLAIN;

# Now try to fill them in from the XML.
%sigla = ();
$idx = 0;
my @ids = ( 'Bzommar 449', 'Jerusalem 1051,1107', 'London OR 5260', 'Venice 887', 'Vienna 574' );
opendir( XML, $testdir_xml ) or die "Could not open XML file dir: $@";
push( @json, { 'witnesses' => [] } );  # element 1
while ( my $fn = readdir( XML ) ) {
	next if $fn =~ /^\./;
    # Parse the file
    my $xmlparser = XML::LibXML->new();
    my $doc;
    eval { $doc = $xmlparser->parse_file( "$testdir_xml/$fn" )->documentElement(); };
    ok( defined $doc, "parsed the XML file $fn" );
    my $ms_obj = Text::TEI::Collate::Manuscript->new( 
	'source' => $doc,
	'sourcetype' => 'xmldesc' 
	);
    is( $ms_obj->identifier, $ids[$idx], "Manuscript has correct ID" );
    ok( $ms_obj->sigil(), "sigil was auto-assigned as " . $ms_obj->sigil() );
    ok( !defined( $sigla{$ms_obj->sigil()} ), "sigil not already in use" );
    $sigla{$ms_obj->sigil()} = $fn;
    
    # Do we have words?
    my @placeholders = grep { $_->placeholders } @{$ms_obj->words};
    is( scalar @placeholders, $ph_count[$idx], "Word list has correct number of division placeholders" );
    is( scalar @{$ms_obj->words}, $wordcount[$idx], "Manuscript has correct number of words" );
	# Would test for the right words only some of the letters have changed to numbers...
    push( @{$json[1]->{'witnesses'}}, $ms_obj->tokenize_as_json );
	$idx++;
}
close XML;

%sigla = ();
$idx = 0;
# Some wordcounts have changed for the sake of collation tests.
my @orig_wordcount;
push( @orig_wordcount, @wordcount);
$wordcount[2] = 128;
$wordcount[4] = 196;
$ph_count[4] = 1;
opendir( XMLFULL, $testdir_xmlfull ) or die "Could not open XML file dir: $@";
push( @json, { 'witnesses' => [] } );  # element 2
while ( my $fn = readdir( XMLFULL ) ) {
    next if $fn =~ /^\./;
    # Parse the file
    my $xmlparser = XML::LibXML->new();
    my $doc;
    eval { $doc = $xmlparser->parse_file( "$testdir_xmlfull/$fn" )->documentElement(); };
    ok( defined $doc, "parsed the XML file $fn" );
    my $ms_obj = Text::TEI::Collate::Manuscript->new( 
	'sourcetype' => 'xmldesc',
	'source' => $doc,
	);
    is( $ms_obj->identifier, $ids[$idx], "Manuscript has correct ID" );
    ok( $ms_obj->sigil(), "sigil was auto-assigned as " . $ms_obj->sigil() );
    ok( !defined( $sigla{$ms_obj->sigil()} ), "sigil not already in use" );
    $sigla{$ms_obj->sigil()} = $fn;

    # Do we have words?
    my @placeholders = grep { $_->placeholders } @{$ms_obj->words};
    my $words = scalar @{$ms_obj->words};
    is( scalar @placeholders, $ph_count[$idx], "Word list has correct number of division placeholders" );
    is( $words, $wordcount[$idx++], "Manuscript has $words words" );
    push( @{$json[2]->{'witnesses'}}, $ms_obj->tokenize_as_json );
}
close XMLFULL;

# Now test the JSON tokenization objects we created from each version
# of the file.  They should all be identical.
$DB::single = 1;
foreach my $idx ( 0 .. $#wordcount ) {
	# Test the wordcounts.
	is( scalar @{$json[0]->{witnesses}->[$idx]->{tokens}}, $orig_wordcount[$idx], "Got correct number of words from JSON" );
	is( scalar @{$json[1]->{witnesses}->[$idx]->{tokens}}, $orig_wordcount[$idx], "Got correct number of words from JSON" );
	is( scalar @{$json[2]->{witnesses}->[$idx]->{tokens}}, $wordcount[$idx], "Got correct number of words from JSON" );
	
	# Test the content tokens for plaintext.
	my $t = $text[$idx];
	$t =~ s/[[:punct:]]//g;
	is( join( ' ', map { $_->{t} } @{$json[0]->{witnesses}->[$idx]->{tokens}} ), $t, "Got correct words in JSON tokens" );
}

