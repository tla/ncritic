#!/usr/bin/perl -w -CDS

use strict;
use lib 'lib';
use Data::Dumper;
use Text::WagnerFischer::Armenian qw( distance );
use Text::TEI::Collate;
use Words::Armenian;
use XML::LibXML;

eval { no warnings; binmode $DB::OUT, ":utf8"; };

my( @files ) = @ARGV;

# and how fuzzy a match we can tolerate.
my $fuzziness = "50";  # this is n%

my $aligner = Text::TEI::Collate->new( 'fuzziness' => $fuzziness,
				       'debug' => 2,
				       'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
				       'canonizer' => \&Words::Armenian::canonize_word,
				       'TEI' => 1,
    );


my @results = $aligner->align( @files );

my $ns_uri = 'http://www.tei-c.org/ns/1.0';
my $doc = XML::LibXML->createDocument( '1.0', 'UTF-8' );
my $root = $doc->createElementNS( $ns_uri, 'TEI' );
# TODO: create the header
$doc->setDocumentElement( $root );

# Get the new base.  This should have all the links.
my $initial_base = $aligner->generate_base( map { $_->words } @results );
# Undef if not begun, 1 if begun and not ended, 0 if ended
my %text_active;
my $in_app = 0;
my @app_waiting = ();
foreach my $idx ( 0 .. $#{$initial_base} ) {
    my $word_obj = $initial_base->[$idx];
    next unless $word_obj->word || $word_obj->placeholder;
    my @links = $word_obj->links;
    my @variants = $word_obj->variants;
    foreach my $w ( map { $_->words->[$idx] } @results ) {
	$text_active{$w->ms_sigil} = 1 if $w->placeholder && $w->placeholder eq '__BEGIN__';
	$text_active{$w->ms_sigil} = 0 if $w->placeholder && $w->placeholder eq '__END__';
    }

    # Get all the words; if all active texts are accounted for make the
    # single word an app.  If not, open/add to an app until the next row
    # in which all active texts are accounted for.
    my %text_unseen;
    map { $text_unseen{$_} = 1 if $text_active{$_} } keys( %text_active );
    
    my @line_words;
    # The main word makes a group in %line_words, and then each variant
    # makes its own group.
    # line_words = { word1 => [ s1, s2, ... ],
    #                word2 => [ s3, s4, ... ] },
    #              { other1 => [ s1, s2, ... ]
    #                other2 => [ s3, s4, ... ] },
    push( @line_words, class_words( $word_obj, \%text_unseen ) );
    foreach( @variants ) {
	push( @line_words, class_words( $_, \%text_unseen ) );
    }
    
    # Either make the apparatus entry, or defer it.
    if( keys( %text_unseen ) ) {
	push( @app_waiting, \@line_words );
	$in_app = 1;
    } else {
	if( $in_app ) {
	    make_app( @app_waiting );
	    $in_app = 0;
	}
	make_app( \@line_words );
    }
}

print $doc->toString(1);
    
print "Done.\n";

# Returns a hashref that has looked at the punct-free forms of each
# word and grouped the identical witnesses.  Take each ms we see out
# of the 'unseen' array that was passed in.
sub class_words {
    my( $word_obj, $unseen ) = @_;
    my $varhash = {};
    $varhash->{ $word_obj->word } = [ $word_obj->ms_sigil ];
    delete $unseen->{ $word_obj->ms_sigil };
    foreach my $w ( $word_obj->links ) {
	if( exists $varhash->{ $w->word } ) {
	    push( @{$varhash->{ $w->word }}, $w->ms_sigil );
	} else {
	    $varhash->{ $w->word } = [ $w->ms_sigil ];
	}
	delete $unseen->{ $w->ms_sigil };
    }
    return $varhash;
}

# Write out the apparatus entry to our root element.
sub make_app {
    my( @app_entries ) = @_;
    my $app = $root->addNewChild( $ns_uri, 'app' );
    if( scalar( @app_entries ) == 1 ) {
	my $line_entry = $app_entries[0];
	foreach my $entry ( @$line_entry ) {
	    # $entry is a hash; one entry per rdgGrp.
	    my $rdg_grp = $app->addNewChild( $ns_uri, 'rdgGrp' );
	    $rdg_grp->setAttribute( 'type', 'subvariants' );
	    foreach my $rdg_word ( keys %$entry ) {
		my $wits = $entry->{$rdg_word};
		my $wit_string = join( ' ', map { '#'.$_ } @$wits );
		my $rdg = $rdg_grp->addNewChild( $ns_uri, 'rdg' );
		$rdg->setAttribute( 'wit', $wit_string );
		$rdg->appendText( $rdg_word );
	    }
	}
    } else {
	# Combine the entries into distinct phrases, keyed by sigil.
	my %phrases;
	foreach my $entry ( @app_entries ) {
	    foreach my $reading ( @$entry ) {
		foreach my $word ( keys %$reading ) {
		    foreach my $sigil ( @{$reading->{$word}} ) {
			if( $phrases{$sigil} ) {
			    $phrases{$sigil} .= " $word";
			} else {
			    $phrases{$sigil} = $word;
			}
		    }
		}
	    }
	}
	
	# Now invert the hash, so to speak.
	my %distinct_phrases = invert_hash( %phrases );
	foreach my $phrase ( keys %distinct_phrases ) {
	    my $wit_string = join( ' ', map { '#'.$_ } 
				   @{$distinct_phrases{$phrase}} );
	    my $rdg = $app->addNewChild( $ns_uri, 'rdg' );
	    $rdg->setAttribute( 'wit', $wit_string );
	    $rdg->appendText( $phrase );
	}
    }
}

sub invert_hash {
    my %hash = @_;
    my %new_hash;
    foreach my $key ( keys %hash ) {
	my $val = $hash{$key};
	if( exists ( $new_hash{$val} ) ) {
	    push( @{$new_hash{$val}}, $key );
	} else {
	    $new_hash{$val} = [ $key ];
	}
    }
    return %new_hash;
}
	
