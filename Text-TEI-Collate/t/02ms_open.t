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
opendir( PLAIN, $testdir_plain ) or die "Could not open plaintext file dir: $@";
my $idx = 0;
my @text;
while( my $fn = readdir( PLAIN ) ) {
    next if $fn =~ /^\./;
    my $fh = new IO::File;
    $fh->open( "$testdir_plain/$fn", "<:utf8" );
    ok( defined $fh, "opened file $fn" );
    my $lines = join( '', <$fh> );
    $fh->close;
    my $ms_obj = Text::TEI::Collate::Manuscript->new( 'identifier' => $fn,
						      'source' => $lines );
    is( ref $ms_obj, 'Text::TEI::Collate::Manuscript', "created manuscript object" );
    is( $ms_obj->identifier(), $fn, "has the right identifier" );
    ok( $ms_obj->sigil(), "sigil was auto-assigned as " . $ms_obj->sigil() );
    ok( !defined( $sigla{$ms_obj->sigil()} ), "sigil not already in use" );
    $sigla{$ms_obj->sigil()} = $fn;
    is( scalar @{$ms_obj->words}, $wordcount[$idx++], "file has correct number of words" );
    push( @text, $ms_obj->words ) if $idx == 4;
}
close PLAIN;

# Now try to fill them in from the XML.
%sigla = ();
$idx = 0;
my @ids = ( 'Bzommar 449', 'Jerusalem 1051,1107', 'London OR 5260', 'Venice 887', 'Vienna 574' );
opendir( XML, $testdir_xml ) or die "Could not open XML file dir: $@";
while ( my $fn = readdir( XML ) ) {
    next if $fn =~ /^\./;
    # Parse the file
    my $xmlparser = XML::LibXML->new();
    my $doc;
    eval { $doc = $xmlparser->parse_file( "$testdir_xml/$fn" )->documentElement(); };
    ok( defined $doc, "parsed the XML file $fn" );
    my $ms_obj = Text::TEI::Collate::Manuscript->new( 'source' => $doc,
	                                              'type' => 'xmldesc' );
    is( $ms_obj->identifier, $ids[$idx], "Manuscript has correct ID" );
    ok( $ms_obj->sigil(), "sigil was auto-assigned as " . $ms_obj->sigil() );
    ok( !defined( $sigla{$ms_obj->sigil()} ), "sigil not already in use" );
    $sigla{$ms_obj->sigil()} = $fn;
    
    # Do we have words?
    my @placeholders = grep { $_->placeholders } @{$ms_obj->words};
    is( scalar @placeholders, $ph_count[$idx], "Word list has correct number of division placeholders" );
    is( scalar @{$ms_obj->words}, $wordcount[$idx++], "Manuscript has correct number of words" );
    my @real_words = grep { !($_->placeholders) } @{$ms_obj->words};
    push( @text, \@real_words ) if $idx == 4;
}
close XML;

%sigla = ();
$idx = 0;
# Some wordcounts have changed for the sake of collation tests.
$wordcount[2] = 128;
$wordcount[4] = 196;
$ph_count[4] = 1;
opendir( XMLFULL, $testdir_xmlfull ) or die "Could not open XML file dir: $@";
while ( my $fn = readdir( XMLFULL ) ) {
    next if $fn =~ /^\./;
    # Parse the file
    my $xmlparser = XML::LibXML->new();
    my $doc;
    eval { $doc = $xmlparser->parse_file( "$testdir_xmlfull/$fn" )->documentElement(); };
    ok( defined $doc, "parsed the XML file $fn" );
    my $ms_obj = Text::TEI::Collate::Manuscript->new( 'type' => 'xmldesc',
						      'source' => $doc );
    is( $ms_obj->identifier, $ids[$idx], "Manuscript has correct ID" );
    ok( $ms_obj->sigil(), "sigil was auto-assigned as " . $ms_obj->sigil() );
    ok( !defined( $sigla{$ms_obj->sigil()} ), "sigil not already in use" );
    $sigla{$ms_obj->sigil()} = $fn;

    # Do we have words?
    my @placeholders = grep { $_->placeholders } @{$ms_obj->words};
    my $words = scalar @{$ms_obj->words};
    is( scalar @placeholders, $ph_count[$idx], "Word list has correct number of division placeholders" );
    is( $words, $wordcount[$idx++], "Manuscript has $words words" );
    my @real_words = grep { !($_->placeholders) } @{$ms_obj->words};
    push( @text, \@real_words ) if $idx == 4;
}
close XMLFULL;

# foreach my $i ( 0 .. $#{$text[0]} ) {
#     my $w1 = $i < scalar @{$text[0]} ? $text[0]->[$i]->original_form : '';
#     my $w2 = $i < scalar @{$text[1]} ? $text[1]->[$i]->original_form : '';
#     my $w3 = $i < scalar @{$text[2]} ? $text[2]->[$i]->original_form : '';
#     printf( "%-20s%-20s%-20s\n", $w1, $w2, $w3 );
# }
