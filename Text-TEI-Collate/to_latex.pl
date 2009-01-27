#!/usr/bin/perl -w -CDS

use strict;
use lib 'lib';
use Date::Format;
use Getopt::Long;
use XML::LibXML;
use Words::Armenian qw( am_downcase );

eval { no warnings; binmode $DB::OUT, ":utf8"; };

my( $infile, $outfile, $lang_module, $include_orthography, $include_spelling );

GetOptions( 
    'i|infile=s' => \$infile,
    'o|outfile=s' => \$outfile,
    'orth' => \$include_orthography,
    'spell' => \$include_spelling,
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
$include_spelling = 1 if $include_orthography;
# TODO pull this entirely from XML.
my %orth = %Words::Armenian::ORTHOGRAPHY;
my %spell = %Words::Armenian::SPELLINGS;

my $parser = XML::LibXML->new();
my $input_doc = $parser->parse_file( $infile );
my $ns_uri = 'http://www.tei-c.org/ns/1.0';
my $xpc = XML::LibXML::XPathContext->new( $input_doc );
$xpc->registerNs( 'tei', $ns_uri );

# This is where the action happens.
open( OUT, ">$outfile" ) or die "Could not open $outfile for writing: $@";
binmode( OUT, ':utf8' );
write_header();
latex_conv();
print OUT "\\end{document}\n";
print STDERR "Done.\n";

sub write_header {

    # Get the title.
    my $title = $xpc->findvalue( '//tei:titleStmt/tei:title[text()]' );
    my $date = time2str( "%e %b %Y", time() );

    while( <DATA> ) {  # Read in the header from below.
	s/__TITLE__/$title/;
	s/__DATE__/$date/;
	if( /__WITNESSLIST__/ ) {
	    
	    my @wit_list = $xpc->findnodes( '//tei:listWit/tei:witness' );
	    if( @wit_list ) {
		print OUT "\\begin\{tabular\}\{ll\}\n";
		foreach my $witness ( @wit_list ) {
		    print OUT $witness->getAttribute( 'xml:id' )
			. ' & ' . $witness->textContent() . "\\\\\n";
		}
		print OUT "\\end\{tabular\}\n";
	    } else {
		warn "No witnesses found in header!!";
	    }
	} else {
	    print OUT $_;
	}
    }
}

sub latex_conv {
    # First get the divs and the paragraphs
    my $div_counter = 0;
    foreach my $section ( $xpc->findnodes( '//tei:div' ) ) {
	$div_counter++;
	print OUT "\\pagebreak\n" unless $div_counter == 1;
	print OUT "\\subsection\{Section $div_counter\}\n\n";
	print OUT "\\beginnumbering\n";

	# Then the paragraphs.
	foreach my $pg ( $xpc->findnodes( './/tei:p', $section ) ) {
	    my @words_out;
	    my %last_word;
	    my %need_anchor;
	    foreach my $app ( $xpc->findnodes( './/tei:app', $pg ) ) {
		my $app_id = $app->getAttribute( 'xml:id' ) || '';
		my $lemma = $xpc->find( './/tei:lem', $app );
		my $false_lemma = 0;
		my $rdg_xpath = './/tei:rdg';
		# TODO I really want to pick the right readings via xpath.
		# print STDERR "Searching on $rdg_xpath\n";
		my @readings = $xpc->findnodes( $rdg_xpath, $app );
		if( $lemma ) {
		    $lemma = $lemma->get_node( 1 );
		} else {
		    # Follow A for now.  Ignore other readings.
		    foreach( @readings ) {
			if( $_->getAttribute( 'wit' ) =~ /\#A/ ) {
			    $lemma = $_;
			}
		    }
		    $false_lemma = 1;
		    @readings = ();
		}

		unless( $lemma ) {
		    warn "No lemma and no A reading for app $app_id";
		    next;
		}
		# Get all the notes within this apparatus.
		my @notes = $xpc->findnodes( './/tei:note', $app );
		
		my $lem_txt = extract_text( $lemma, 1, $false_lemma );
		# For dictionary comparison
		my $lem_str = $lem_txt;
		$lem_str =~ s/\\arm\{(.*)\}/$1/;
		$lem_str =~ s/[[:punct:]]//g;
		$lem_str = am_downcase( $lem_str );

		my $app_footnote;  # For the apparatus.
		my $ed_footnote = '';   # For editorial notes.

		# Get any readings.
		my @rdg_out;
		foreach my $r( @readings ) {
		    my $wits = witness_string( $r->getAttribute( 'wit' ) );
		    my( $txt ) = extract_text( $r );
		    my $rdg_str = $txt;
		    $rdg_str =~ s/\\arm\{(.*)\}/$1/;
		    $rdg_str =~ s/[[:punct:]]//g;
		    $rdg_str = am_downcase( $rdg_str );

		    unless( $include_orthography ) {
			next if $rdg_str eq $lem_str;
			next if ( exists $orth{$rdg_str}
				  && $orth{$rdg_str} eq $lem_str );
		    }
		    unless( $include_spelling ) {
			next if ( exists $spell{$rdg_str} 
				  && $spell{$rdg_str} eq $lem_str );
		    }
		    
		    push( @rdg_out, { 'txt' => $txt, 'wit' => $wits } );
		}

		# Get any editorial notes.
		foreach my $n ( @notes ) {
		    # Assume only one note per apparatus for now.
		    warn "More than one note for app $app_id" if $ed_footnote;
		    $ed_footnote .= $n->textContent;
		}

		# Now construct the LaTeX expression.
		# Do we have a lemma to hang it all on?
		if( $lem_txt ) {
		    # TODO Check for orphaned footnotes
		    if( keys %need_anchor ) {
			rehome_orphans( \@rdg_out, \@notes,
					$need_anchor{'rdg'},
					$need_anchor{'notes'} );
		    }
			
		    my $latex_app = latex_for_lemma( $lem_txt, \@rdg_out,
						     \@notes );
		    push( @words_out, $latex_app );
		    %last_word = ( 'lemma' => $lem_txt,
				   'readings' => \@rdg_out,
				   'notes' => \@notes, );
		    %need_anchor = ();
		} else {
		    # We have no lemma.  If there is a previous lemma
		    # available, hang the reading on that.  Otherwise
		    # store it to hang on the next word.
		    if( exists $last_word{'lemma'} ) {
			my $lem_rdg = $last_word{'readings'};
			my $lem_notes = $last_word{'notes'};
			rehome_orphans( $lem_rdg, $lem_notes, 
					\@rdg_out, \@notes );
			pop( @words_out );
			push( @words_out, latex_for_lemma( $last_word{'lemma'},
							   $lem_rdg,
							   $lem_notes ) );

		    } else {
			_add_hash_entry( \%need_anchor, 'rdg', \@rdg_out );
			_add_hash_entry( \%need_anchor, 'notes', \@notes );
		    }
		}

	    } # foreach app

	    print OUT "\n\\pstart\n";
	    print OUT join( ' ', @words_out );
	    print OUT "\n\\pend\n";
	}  # foreach paragraph
	print OUT "\\endnumbering\n";
    } # foreach div

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

sub latex_for_lemma {
    my( $lemma, $rdg_list, $note_list ) = @_;

    my $latex_app;
    my $app_footnote = join( '; ', map { $_->{txt} . ": " .
					  $_->{wit} } @$rdg_list );
    my $ed_footnote .= join( ' // ', map { $_->textContent } @$note_list );
    
    if( $app_footnote || $ed_footnote ) {
	my $latex_fn = '';
	if( $app_footnote ) {
	    $latex_fn .= "\\Afootnote\{$app_footnote\}";
	}
	if( $ed_footnote ) {
	    $latex_fn .= "\\Bfootnote\{$ed_footnote\}";
	}
	$latex_app =  sprintf( '\\edtext{%s}{%s}', 
			       $lemma, $latex_fn );
    } else {
	$latex_app = $lemma;
    }
}

# Add the contents of $orph_* to the reading & note arrays.
sub rehome_orphans {
    my( $readings, $notes, $orph_rdgs, $orph_notes ) = @_;
    
    # Notes are easy.  Do them first.
    push( @$notes, @$orph_notes );
    
    # Readings are hard.  We have to break them down and
    # join them back up.
    my $witness_rdg = {};  # keyed by sigil
    my @all_readings = @$readings;
    foreach( @$orph_rdgs ) {
	push( @all_readings, @$_ );
    }
    foreach my $rdg( ( @all_readings ) ) {
	foreach my $wit ( split( /\s+/, $rdg->{'wit'} ) ) {
	    _add_hash_entry( $witness_rdg, $wit, $rdg->{'txt'} );
	}
    }
    foreach my $wit( keys %$witness_rdg ) {
	# Join up the strngs.
	my $reading_str = join( ' ', @{$witness_rdg->{$wit}} );
	$witness_rdg->{$wit} = $reading_str;
    }

    my %joined_rdgs = invert_hash( $witness_rdg );
    $readings = [];
    foreach my $rdg_txt ( keys %joined_rdgs ) {
	push( @$readings, { 'txt' => $rdg_txt,
			    'wit' => join( ' ', @{$joined_rdgs{$rdg_txt}}) } );
    }
    
}
    

sub extract_text {
    my ( $rdg, $is_lemma, $false_lemma ) = @_;

    my $out_str = '';
    if( $rdg->hasAttribute( 'type' ) 
	&& $rdg->getAttribute( 'type' ) eq 'omission'
	&& !$is_lemma ) {
	$out_str = '\emph{om.}';
    } elsif( !$rdg->textContent() && !$is_lemma ) {
	warn "Empty reading not marked as omission";
	$out_str = '\emph{om.}';
    } else {
	my @words;
	foreach my $word ( $xpc->findnodes( 'tei:w', $rdg ) ) {
	    my $word_str = $word->textContent;
	    my $word_id = $word->getAttribute( 'xml:id' );
	    if( $false_lemma && $word_id ) {
		my $xpathExp = 'tei:witDetail[@target=' . "'\#$word_id' and "
		    . '@type=\'punctuation\']';
		my @details = $xpc->findnodes( $xpathExp, $rdg );
		foreach my $det ( @details ) {
		    if( $det->getAttribute( 'wit' ) =~ /\#A/ ) {
			$word_str .= $det->textContent;
		    }
		}
	    }
	    push( @words, $word_str );
	}
	# if( @words ) {
	    $out_str = '\\arm{' . join( ' ', @words ) . '}';
	# }
    }
    return( $out_str );
}

sub _add_hash_entry {
    my( $hash, $key, $entry ) = @_;
    if( exists( $hash->{$key} ) ) {
	push( @{$hash->{$key}}, $entry );
    } else {
	$hash->{$key} = [ $entry ];
    }
}

sub invert_hash {
    my ( $hash, $plaintext_keys ) = @_;
    my %new_hash;
    foreach my $key ( keys %$hash ) {
	my $val = $hash->{$key};
	my $valkey = $val;
	if( $plaintext_keys 
	    && ref( $val ) ) {
	    $valkey = $plaintext_keys->{ scalar( $val ) };
	    warn( "No plaintext value given for $val" ) unless $valkey;
	}
	if( exists ( $new_hash{$valkey} ) ) {
	    push( @{$new_hash{$valkey}}, $key );
	} else {
	    $new_hash{$valkey} = [ $key ];
	}
    }
    return %new_hash;
}

__DATA__
\documentclass[a4paper]{article} 
\usepackage{fullpage}
\usepackage{setspace}
\usepackage[lmargin=1.25in]{geometry}
\usepackage{ledmac} 
\usepackage{setspace}
\usepackage[UKenglish]{babel} % For English hypenation. 
\usepackage{fontspec}

%% Fontspec stuff
\newfontinstance\armfont[Bold=Mshtakan Bold,Italic=Mshtakan Oblique,BoldItalic=Mshtakan BoldOblique]{Mshtakan}
\newcommand{\arm}[1]{{\armfont #1}}
\newfontinstance\gkfont[Scale=0.75]{Lucida Grande}
\newcommand{\gk}[1]{{\gkfont #1}}
\newfontinstance\jefont{Times}
\newcommand{\je}{{\jefont ǰ}}
\setromanfont[Mapping=tex-text]{Palatino}
\defaultfontfeatures{Mapping=tex-text}

%% Ledmac stuff
\setcounter{firstlinenum}{1} 
\setcounter{linenumincrement}{1} 
%% Show some B series familiar footnotes, lettered and paragraphed 
\renewcommand*{\thefootnoteB}{\alph{footnoteB}} 
\footparagraphX{B} 
%% no endnotes 
\noendnotes 
%% narrow sidenotes 
\setlength{\ledrsnotewidth}{4em} 
\title{__TITLE__} 
\author{Tara L Andrews}
\date{__DATE__} 
\begin{document} 
\maketitle 

\section{List of witnesses} 

__WITNESSLIST__

\pagebreak
\section{Text}
