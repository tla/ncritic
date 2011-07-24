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
my $aligner = Text::TEI::Collate->new();
my @mss = $aligner->read_source( 't/data/cx/john18-2.xml' );
$aligner->align( @mss );
my $cols = 74;
foreach( @mss ) {
	is( scalar @{$_->words}, $cols, "Got correct collated columns for " . $_->sigil);
}

#TODO test the actual collation validity sometime
}



# =begin testing
{
use Text::TEI::Collate;

my @test = (
    'the black dog had his day',
    'the white dog had her day',
    'the bright red dog had his day',
    'the bright white cat had her day',
);
my $aligner = Text::TEI::Collate->new();
my @mss = map { $aligner->read_source( $_ ) } @test;
$aligner->align( @mss );
my $base = $aligner->generate_base( @mss );
# Get rid of the specials
pop @$base;
shift @$base;
is( scalar @$base, 8, "Got right number of words" );
is( $base->[0]->word, 'the', "Got correct first word" );
is( scalar $base->[0]->links, 3, "Got 3 links" );
is( scalar $base->[0]->variants, 0, "Got 0 variants" );
is( $base->[1]->word, 'black', "Got correct second word" );
is( scalar $base->[1]->links, 0, "Got 0 links" );
is( scalar $base->[1]->variants, 1, "Got 1 variant" );
is( $base->[1]->get_variant(0)->word, 'bright', "Got correct first variant" );
is( scalar $base->[1]->get_variant(0)->links, 1, "Got a variant link" );
is( $base->[2]->word, 'white', "Got correct second word" );
is( scalar $base->[2]->links, 1, "Got 1 links" );
is( scalar $base->[2]->variants, 0, "Got 0 variants" );
is( $base->[3]->word, 'red', "Got correct third word" );
is( scalar $base->[3]->links, 0, "Got 0 links" );
is( scalar $base->[3]->variants, 1, "Got a variant" );
is( $base->[3]->get_variant(0)->word, 'cat', "Got correct second variant" );
is( scalar $base->[3]->get_variant(0)->links, 0, "Variant has no links" );
is( $base->[4]->word, 'dog', "Got correct fourth word" );
is( scalar $base->[4]->links, 2, "Got 2 links" );
is( scalar $base->[4]->variants, 0, "Got 0 variants" );
is( $base->[5]->word, 'had', "Got correct fifth word" );
is( scalar $base->[5]->links, 3, "Got 3 links" );
is( scalar $base->[5]->variants, 0, "Got 0 variants" );
is( $base->[6]->word, 'his', "Got correct sixth word" );
is( scalar $base->[6]->links, 1, "Got 1 link" );
is( scalar $base->[6]->variants, 1, "Got 1 variant" );
is( scalar $base->[6]->get_variant(0)->links, 1, "Got 1 variant link" );
is( $base->[6]->get_variant(0)->word, 'her', "Got correct third variant");
is( $base->[7]->word, 'day', "Got correct seventh word" );
is( scalar $base->[7]->links, 3, "Got 3 links" );
is( scalar $base->[7]->variants, 0, "Got 0 variants" );
}



# =begin testing
{
use Test::More::UTF8;
use Text::TEI::Collate;
use Text::TEI::Collate::Word;

my $base_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'հարիւրից' );
my $variant_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'զ100ից' );
my $match_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'զհարիւրից' );
my $new_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => '100ից' );
my $different_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'անգամ' );


my $aligner = Text::TEI::Collate->new();
$base_word->add_variant( $variant_word );
is( $aligner->word_match( $base_word, $match_word), $base_word, "Matched base word" );
is( $aligner->word_match( $base_word, $new_word), $variant_word, "Matched variant word" );
is( $aligner->word_match( $base_word, $different_word), undef, "Did not match irrelevant words" );

my( $ms1 ) = $aligner->read_source( 'Jn bedwange harde swaer Doe riepen si op gode met sinne' );
my( $ms2 ) = $aligner->read_source( 'Jn bedvanghe harde suaer. Doe riepsi vp gode met sinne.' );
$aligner->make_fuzzy_matches( $ms1->words, $ms2->words );
is( scalar keys %{$aligner->{fuzzy_matches}}, 15, "Got correct number of vocabulary words" );
my %unique;
map { $unique{$_} = 1 } values %{$aligner->{fuzzy_matches}};
is( scalar keys %unique, 11, "Got correct number of fuzzy matching words" );
}



# =begin testing
{
use Test::More::UTF8;
use Text::TEI::Collate;

my $aligner = Text::TEI::Collate->new();
ok( $aligner->_is_near_word_match( 'Արդ', 'Արդ' ), "matched exact string" );
ok( $aligner->_is_near_word_match( 'հաւասն', 'զհաւասն' ), "matched near-exact string" );
ok( !$aligner->_is_near_word_match( 'հարիւրից', 'զ100ից' ), "did not match differing string" );
ok( !$aligner->_is_near_word_match( 'ժամանակական', 'զշարագրական' ), "did not match differing string 2" );
ok( $aligner->_is_near_word_match( 'ընթերցողք', 'ընթերցողսն' ), "matched near-exact string 2" );
ok( $aligner->_is_near_word_match( 'պատմագրացն', 'պատգամագրացն' ), "matched pretty close string" );
}



# =begin testing
{
my $aligner = Text::TEI::Collate->new();
my @mss = $aligner->read_source( 't/data/cx/john18-2.xml' );
$aligner->align( @mss );
my $jsondata = $aligner->to_json( @mss );
ok( exists $jsondata->{alignment}, "to_json: Got alignment data structure back");
my @wits = @{$jsondata->{alignment}};
is( scalar @wits, 28, "to_json: Got correct number of witnesses back");
my $columns = 74;
foreach ( @wits ) {
	is( scalar @{$_->{tokens}}, $columns, "to_json: Got correct number of words back for witness")
}
}



# =begin testing
{
use lib 't/lib';
use Text::TEI::Collate;
use Text::WagnerFischer::Armenian;
use Words::Armenian;
use XML::LibXML::XPathContext;
# Get an alignment to test with
my $testdir = "t/data/xml_plain";
opendir( XF, $testdir ) or die "Could not open $testdir";
my @files = readdir XF;
my @mss;
my $aligner = Text::TEI::Collate->new(
	'fuzziness' => '50',
	'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
	);
foreach ( sort @files ) {
	next if /^\./;
	push( @mss, $aligner->read_source( "$testdir/$_",
		'canonizer' => \&Words::Armenian::canonize_word
		) );
}
$aligner->align( @mss );

my $doc = $aligner->to_tei( @mss );
is( ref( $doc ), 'XML::LibXML::Document', "Made TEI document header" );
my $xpc = XML::LibXML::XPathContext->new( $doc->documentElement );
$xpc->registerNs( 'tei', $doc->documentElement->namespaceURI );

# Test the creation of a document header from TEI files
my @witdesc = $xpc->findnodes( '//tei:witness/tei:msDesc' );
is( scalar @witdesc, 5, "Found five msdesc nodes");

# Test the creation of apparatus entries
my @apps = $xpc->findnodes( '//tei:app' );
is( scalar @apps, 111, "Got the correct number of app entries");
my @words_not_in_app = $xpc->findnodes( '//tei:body/tei:div/tei:p/tei:w' );
is( scalar @words_not_in_app, 171, "Got the correct number of matching words");
my @details = $xpc->findnodes( '//tei:witDetail' );
my @detailwits;
foreach ( @details ) {
	my $witstr = $_->getAttribute( 'wit' );
	push( @detailwits, split( /\s+/, $witstr ));
}
is( scalar @detailwits, 13, "Found the right number of witness-detail wits");

# TODO test the reconstruction of witnesses from the parallel-seg.
}



# =begin testing
{
use lib 't/lib';
use Text::TEI::Collate;
use Text::WagnerFischer::Armenian;
use Words::Armenian;
use XML::LibXML::XPathContext;

eval 'require Graph::Easy;';
unless( $@ ) {
# Get an alignment to test with
my $testdir = "t/data/xml_plain";
opendir( XF, $testdir ) or die "Could not open $testdir";
my @files = readdir XF;
my @mss;
my $aligner = Text::TEI::Collate->new(
	'fuzziness' => '50',
	'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
	);
foreach ( sort @files ) {
	next if /^\./;
	push( @mss, $aligner->read_source( "$testdir/$_",
		'canonizer' => \&Words::Armenian::canonize_word
		) );
}
$aligner->align( @mss );

my $graph = $aligner->to_graph( @mss );

is( ref( $graph ), 'Graph::Easy', "Got a graph object from to_graph" );
is( scalar( $graph->nodes ), 381, "Got the right number of nodes" );
is( scalar( $graph->edges ), 992, "Got the right number of edges" );
}
}




1;
