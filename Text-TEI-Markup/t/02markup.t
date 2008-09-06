#!/usr/bin/perl;

use strict;
use Test::More tests => 91;
use Text::TEI::Markup qw( to_xml word_tag_wrap );
use XML::LibXML;

binmode STDOUT, ":utf8";
my $tb = Test::Builder->new;
binmode $tb->output,         ':encoding(UTF-8)';
binmode $tb->failure_output, ':encoding(UTF-8)';
binmode $tb->todo_output,    ':encoding(UTF-8)';

my %opts = (
    file => "t/data/test.txt",
    wrap_words => 1,
    number_conversion => \&number_value,
    # Using the default template
    # Using the default ( utf8 ) file encoding
);    

my $xml;
ok( $xml = to_xml( %opts ), "Parsed markup without wrapping" );
my $parser = XML::LibXML->new();
my $doc;
ok( $doc = $parser->parse_string( $xml ), "parsed our result XML" );
my $root = $doc->documentElement;

# Some basic tests.  Make sure some header keys are subbed correctly,
# and that there is one body, and that there are the correct number of
# divs and ps and lbs and the like, and that adds & dels & substs have
# the right values.

my @titles;
ok( @titles = $root->getElementsByTagName( 'titleStmt' ), "got title" );
my @title_child = $titles[0]->getChildrenByTagName( 'title' );;
is( $title_child[0]->textContent, "\x{053A}\x{0561}\x{0574}\x{0561}\x{0576}\x{0561}\x{056F}\x{0561}\x{0563}\x{0580}\x{0578}\x{0582}\x{0569}\x{056B}\x{0582}\x{0576}", "title is correct" );
like( $titles[0]->textContent, qr/Tara L Andrews/, "found transcriber" );

my @body = $root->getElementsByTagName( 'body' );
my $body = $body[0];
ok( $body, "found text body" );
my @div = $body->getElementsByTagName( 'div' );
is( scalar @div, 1, "found right number of paragraphs" );
my @pgs = $body->getElementsByTagName( 'p' );
is( scalar @pgs, 2, "found right number of paragraphs" );
my @subst = $body->getElementsByTagName( 'subst' );
is( scalar @subst, 1, "found right number of substitutions" );
my( $found_add, $found_del );
foreach my $schild ( $subst[0]->childNodes() ) {
    if( $schild->nodeName eq 'del' ) {
	$found_del = 1;
	is( $schild->textContent, "\x{570}\x{561}\x{575}\x{578}\x{581}",
	    "right deletion content" );
    } elsif ( $schild->nodeName eq 'add' ) {
	$found_add = 1;
	# Test attribute add
	is( $schild->getAttribute( 'place' ), 'overwrite', 
	    "right add attribute" );
	is( $schild->textContent, 
	    "\x{570}\x{578}\x{57c}\x{578}\x{574}\x{578}\x{581}", 
	    "right add content" );
    }
}
ok( $found_add, "found add tag" );
ok( $found_del, "found del tag" );
# Test tag pass-through
my @supplied = $body->getElementsByTagName( 'supplied' );
is( scalar @supplied, 1, "found pass-through tag" );
is( $supplied[0]->getAttribute( 'reason' ), 'omitted', 
    "pass-through attribute preserved" );
is( $supplied[0]->textContent, "\x{545}", "pass-through content preserved" );

# Pretty well satisfied with non-word-wrapped text.  Go for word wrapping.
my $word_xml;
ok( $word_xml = word_tag_wrap( $xml ), "word-wrap what we have" );
@body = $root->getElementsByTagName( 'body' );
$body = $body[0];
ok( $body, "found text body" );
my @words = $body->getElementsByTagName( 'w' );
is( scalar @words, 33, "found correct number of simple words" );
my @segwords = $body->getElementsByTagName( 'seg' );
is( scalar @segwords, 27, "found correct number of complex words" );
my( $expan_ct, $ex_ct, $lb_ct, $pb_ct );
foreach my $sw ( @segwords ) {
    is( $sw->getAttribute( 'type' ), "word", "seg has type 'word'" );
    like( $sw->textContent, qr/^\S+$/, "no spaces in segmented word" );
    my @lb = $sw->getElementsByTagName( 'lb' );
    $lb_ct += scalar @lb;
    my @pb = $sw->getElementsByTagName( 'pb' );
    $pb_ct += scalar @pb;
    my @expan = $sw->getElementsByTagName( 'expan' );
    $expan_ct += scalar @expan;
    my @ex = $sw->getElementsByTagName( 'ex' );
    $ex_ct += scalar @ex;
    my @num = $sw->getElementsByTagName( 'num' );
    if( @lb ) {
	# Make sure it isn't the last node
	ok( my $node = $lb[0]->nextSibling, "lb has following sibling" );
    }
    if( @pb ) {
	# Make sure it isn't the last node
	ok( my $node = $pb[0]->nextSibling, "pb has following sibling" );
    }
    if( @expan ) {
	# Make sure it has only text siblings
	my @cnodes = $sw->childNodes();
	foreach my $c ( @cnodes ) {
	    unless( $c->isEqual( $expan[0] ) ) {
		is( $c->nodeName, '#text', "expan sibling is text node" );
	    }
	}
    }
    foreach my $n ( @num ) {
	my $rep = $n->textContent();
	my $val = $n->getAttribute( 'value' );
	is( $val, number_value( $rep ), "number value sub passthrough works" );
    }
    foreach my $exn ( @ex ) {
	is( $exn->getAttribute( 'resp' ), '#tla', "ex has right resp set" );
    }
}
is( $lb_ct, "4", "right number of lb tags" );
is( $pb_ct, "1", "right number of pb tags" );
is( $ex_ct, "5", "right number of ex tags" );
is( $expan_ct, "14", "right number of expan tags" );

# A helper sub for converting Armenian numbers.  More than you
# bargained for eh?

sub number_value {
    my $str = shift;
    my @codepoints = unpack( "U*", $str );
    my $total;
    foreach my $digit ( @codepoints ) {
        # Error check.
        if( $digit < 1328 || $digit > 1364 ) {
            warn "string $str appears not to be a number\n";
            return 0;
        }

        # Convert into a number.
        my $val;
        if( $digit < 1338 ) {
            $val = $digit - 1328;
        } elsif( $digit < 1347 ) {
            $val = ( $digit - 1337 ) * 10;
        } elsif( $digit < 1356 ) {
            $val = ( $digit - 1346 ) * 100;
        } else {
            $val = ( $digit - 1355 ) * 1000;
        }

        # Figure out if we are adding or multiplying.
        if( $total && $total < $val ) {
            $total = $total * $val;
        } else {
            $total += $val;
        }
    }

    return $total;
    }


