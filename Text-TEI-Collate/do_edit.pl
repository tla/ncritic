#!/usr/bin/perl -w -CDS

use strict;
use lib 'lib';
use Getopt::Long;
use Words::Armenian;
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
my $output_doc = make_edition( $input_doc );

# Write it all out.
$output_doc->toFile( $outfile, 1 );

print STDERR "Done.\n";

sub make_edition {
    my ( $infile ) = @_;

    # Look for the head and body of the input document
    my $ns_uri = 'http://www.tei-c.org/ns/1.0';
    my $xpc = XML::LibXML::XPathContext->new( $infile );
    $xpc->registerNs( 'tei', $ns_uri );
    my $header = $xpc->find( '//tei:teiHeader' )->get_node( 1 );
    # TODO: separate appLists for each element that can be in <text/>
    my $appList = $xpc->find( '//tei:app' );

    # Create the new document
    my $doc = XML::LibXML->createDocument( '1.0', 'UTF-8' );
    $doc->createProcessingInstruction( 'oxygen', 
			       'RNGSchema="tei_ms_crit.rng" type="xml"' );
    my $root = $doc->createElementNS( $ns_uri, 'TEI' );

    # Clone the header wholesale.
    $root->appendChild( $header->cloneNode( 1 ) );

    # Now make the body, which is the dirty work.
    process_apps( $root, $appList );

    # And finally...
    $doc->setDocumentElement( $root );
    return $doc;
}

sub process_apps {
    my( $root, $app_node_list ) = @_;
    
    # First make a body.
    my $body = $root->addNewChild( $root->namespaceURI, 'text' )->
	addNewChild( $root->namespaceURI, 'body' );

    # Now, for each thing in the app node list, do the following:
    # - Look for section breaks, ask user if we want one
    # - Un-app any words that have no divergence
    # - For each rdgGrp, check %SPELLINGS and ask if necessary
    #   - hmm, need a %NOTSPELLINGS.
    # - Ask what we can't figure out
    # - Ask about punctuation (maybe as a last pass? )

    foreach my $app ( $app_node_list->get_nodelist() ) {
	my $id = $app->getAttribute( 'xml:id' );
	print STDERR "Looking at app $id\n";
	my $xpc = XML::LibXML::XPathContext->new( $app );
	$xpc->registerNs( 'tei', $app->namespaceURI );
	my @groups = $xpc->findnodes( '//tei:rdgGrp' );
	if( @groups ) {
	    print STDERR "Will cope with rdgGrp later\n";
	    # will have to make some choices 
	} else {
	    # no rdgGrp, only rdg.  how many?
	    my @readings = $xpc->findnodes( '//tei:rdg' );
	    if( scalar( @readings ) == 1 ) {
		print STDERR "Accepting an uncontested reading\n";
		# Accept it.
		$readings[0]->setNodeName( 'lem' );
	    }
	}
	$body->appendChild( $app );
    }

    # Finally, return it all.
    return $root;
}
