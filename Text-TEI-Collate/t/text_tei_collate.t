#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
$| = 1;



# =begin testing
{
use Text::TEI::Collate;

my $aligner = Text::TEI::Collate->new();

is( ref( $aligner ), 'Text::TEI::Collate', "Got a Collate object from new()" );
}



# =begin testing
{
use lib 't/lib';
use XML::LibXML;
use Words::Armenian;

my $aligner = Text::TEI::Collate->new();

# Test a manuscript with a plaintext source, filename

my @mss = $aligner->read_source( 't/data/plaintext/test1.txt',
	'identifier' => 'plaintext 1',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object for a plaintext file");
my $ms = pop @mss;
	
is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'A', "Got correct sigil A");
is( scalar( @{$ms->words}), 181, "Got correct number of words in A");

# Test a manuscript with a plaintext source, string
open( T2, "t/data/plaintext/test2.txt" ) or die "Could not open test file";
my @lines = <T2>;
close T2;
@mss = $aligner->read_source( join( '', @lines ),
	'identifier' => 'plaintext 2',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object for a plaintext string");
$ms = pop @mss;

is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'B', "Got correct sigil B");
is( scalar( @{$ms->words}), 183, "Got correct number of words in B");
is( $ms->identifier, 'plaintext 2', "Got correct identifier for B");

# Test two manuscripts with a JSON source
open( JS, "t/data/json/testwit.json" ) or die "Could not read test JSON";
@lines = <JS>;
close JS;
@mss = $aligner->read_source( join( '', @lines ),
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 2, "Got two objects from the JSON string" );
is( ref( $mss[0] ), 'Text::TEI::Collate::Manuscript', "Got manuscript object 1");
is( ref( $mss[1] ), 'Text::TEI::Collate::Manuscript', "Got manuscript object 2");
is( $mss[0]->sigil, 'MsAJ', "Got correct sigil for ms 1");
is( $mss[1]->sigil, 'MsBJ', "Got correct sigil for ms 2");
is( scalar( @{$mss[0]->words}), 182, "Got correct number of words in ms 1");
is( scalar( @{$mss[1]->words}), 263, "Got correct number of words in ms 2");
is( $mss[0]->identifier, 'JSON 1', "Got correct identifier for ms 1");
is( $mss[1]->identifier, 'JSON 2', "Got correct identifier for ms 2");

# Test a manuscript with an XML source
@mss = $aligner->read_source( 't/data/xml_plain/test3.xml',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object from XML file" );
$ms = pop @mss;

is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'BL5260', "Got correct sigil BL5260");
is( scalar( @{$ms->words}), 178, "Got correct number of words in MsB");
is( $ms->identifier, 'London OR 5260', "Got correct identifier for MsB");

my $parser = XML::LibXML->new();
my $doc = $parser->parse_file( 't/data/xml_plain/test3.xml' );
@mss = $aligner->read_source( $doc,
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object from XML object" );
$ms = pop @mss;

is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'BL5260', "Got correct sigil BL5260");
is( scalar( @{$ms->words}), 178, "Got correct number of words in MsB");
is( $ms->identifier, 'London OR 5260', "Got correct identifier for MsB");

## The mss we will test the rest of the tests with.
@mss = $aligner->read_source( 't/data/cx/john18-2.xml' );
is( scalar @mss, 28, "Got correct number of mss from CX file" );
my %wordcount = (
	'base' => 57,
	'P60' => 20,
	'P66' => 55,
	'w1' => 58,
	'w11' => 57,
	'w13' => 58,
	'w17' => 58,
	'w19' => 57,
	'w2' => 58,
	'w21' => 58,
	'w211' => 54,
	'w22' => 57,
	'w28' => 57,
	'w290' => 46,
	'w3' => 56,
	'w30' => 59,
	'w32' => 58,
	'w33' => 57,
	'w34' => 58,
	'w36' => 58,
	'w37' => 56,
	'w38' => 57,
	'w39' => 58,
	'w41' => 58,
	'w44' => 56,
	'w45' => 58,
	'w54' => 57,
	'w7' => 57,
);
foreach( @mss ) {
	is( scalar @{$_->words}, $wordcount{$_->sigil}, "Got correct number of words for " . $_->sigil );
}
}



# =begin testing
{
use lib 't/lib';
use Text::TEI::Collate;
use Words::Armenian;
use XML::LibXML::XPathContext;
# Get an alignment to test with
my $testdir = "t/data/xml_plain";
opendir( XF, $testdir ) or die "Could not open $testdir";
my @files = readdir XF;
my @mss;
my $aligner = Text::TEI::Collate->new();
foreach ( sort @files ) {
	next if /^\./;
	push( @mss, $aligner->read_source( "$testdir/$_",
		'canonizer' => \&Words::Armenian::canonize_word
		) );
}
$aligner->align( @mss );

my $doc = $aligner->to_tei( @mss );
open( RESULT, ">to_tei_result.xml");
print RESULT $doc->toString(1);
close RESULT;
is( ref( $doc ), 'XML::LibXML::Document', "Made TEI document header" );
my $xpc = XML::LibXML::XPathContext->new( $doc->documentElement );
$xpc->registerNs( 'tei', $doc->documentElement->namespaceURI );

# Test the creation of a document header from TEI files
my @witdesc = $xpc->findnodes( '//tei:witness/tei:msDesc' );
is( scalar @witdesc, 5, "Found five msdesc nodes");

# Test the creation of apparatus entries
my @apps = $xpc->findnodes( '//tei:app' );
is( scalar @apps, 174, "Got the correct number of app entries");
my @words_not_in_app = $xpc->findnodes( '//tei:body/tei:div/tei:p/tei:w' );
is( scalar @words_not_in_app, 106, "Got the correct number of matching words");
}




1;
