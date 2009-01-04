#!/usr/bin/perl -w -CDS

use strict;
use lib 'lib';
use Getopt::Long;
use XML::LibXML;

eval { no warnings; binmode $DB::OUT, ":utf8"; };

my( $infile, $outfile, $lang_module );

GetOptions( 
    'i|infile=s' => \$infile,
    'o|outfile=s' => \$outfile,
    );

if( scalar( @ARGV ) == 1 && !$infile ) {
    $infile = shift @ARGV;
} elsif( @ARGV ) {
    warn "Extraneous arguments '@ARGV'";
}
unless( defined( $infile ) && defined( $outfile ) ) {
    print STDERR "Need to define input and output files\n";
    exit;
}

my $parser = XML::LibXML->new();
my $input_doc = $parser->parse_file( $infile );

# This is where the action happens.
open( OUT, ">$outfile" ) or die "Could not open $outfile for writing: $@";
latex_conv( $input_doc );


print STDERR "Done.\n";

sub latex_conv {
    my ( $infile ) = @_;

    # Look for the head and body of the input document
    my $ns_uri = 'http://www.tei-c.org/ns/1.0';
    my $xpc = XML::LibXML::XPathContext->new( $infile );
    $xpc->registerNs( 'tei', $ns_uri );

    my $appList = $xpc->find( '//tei:app' );
    my @words_out;
    foreach my $app ( $appList->get_nodelist() ) {
	my $app_xpc = XML::LibXML::XPathContext->new( $app );
	$app_xpc->registerNs( 'tei', $ns_uri );
	my $lemma = $app_xpc->find( './/tei:lem' );
	my $rdgs = $app_xpc->find( './/tei:rdg' );

	my @readings = $rdgs->get_nodelist();
	if( $lemma ) {
	    $lemma = $lemma->get_node( 1 );
	} else {
	    # Follow A for now.
	    my @tmp;
	    foreach( @readings ) {
		if( $_->getAttribute( 'wit' ) =~ /\#A/ ) {
		    $lemma = $_;
		} else {
		    push( @tmp, $_ );
		}
	    }
	    @readings = @tmp;
	    $lemma = shift @readings unless $lemma;
	}

	my $str;
	my $newline;
	if( @readings ) {
	    my $lem_txt;
	    ( $lem_txt, $newline ) = extract_text( $lemma, 1 );
	    $str = '\edtext{' . $lem_txt . '}{\Afootnote{';
	    my @rdg_out;
	    foreach my $r( @readings ) {
		my $wits = witness_string( $r->getAttribute( 'wit' ) );
		my( $txt, $ignore ) = extract_text( $r, 0 );
		push( @rdg_out, "$txt $wits" );
	    }
	    $str .= join( '; ', @rdg_out );
	    $str .= '}}';
	} else {
	    ( $str, $newline ) = extract_text( $lemma, 1 );
	}
	$str = "\\pend\n\n\\pstart$str" if $newline;
	push( @words_out, $str );
    }

    print OUT join( ' ', @words_out );
}

sub witness_string {
    my $attr_string = shift;
    my @output;
    foreach( split( /\s+/, $attr_string ) ) {
	s/^\#//;
	push( @output, $_ );
    }
    return join( ' ', @output );
}

sub extract_text {
    my ( $node, $is_lemma ) = @_;

    my $out_str = '';
    my $newline;
    if( $node->hasAttribute( 'type' ) 
	&& $node->getAttribute( 'type' ) eq 'omission' ) {
	$out_str = '\emph{om.}';
    } else {
	$out_str = '\arm{';
	foreach my $child( $node->childNodes ) {
	    # should either be w or witDetail
	    if( $child->nodeName eq 'w' ) {
		$out_str .= $child->textContent . ' ';
	    } elsif( $child->nodeName eq 'witDetail' && $is_lemma ) {
		if( $child->getAttribute( 'type' ) eq 'punctuation' ) {
		    $out_str =~ s/\s+$//;
		    $out_str .= $child->textContent . ' ';
		} else {
		    $newline = 1;
		}
	    }
	}
	$out_str =~ s/\s*$/\}/;
    }
    return ( $out_str, $newline );
}
