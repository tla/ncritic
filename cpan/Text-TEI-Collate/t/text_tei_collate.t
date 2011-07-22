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




1;
