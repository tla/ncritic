package ncritic::Controller::MSView;
use Moose;
use namespace::autoclean;
use Convert::Number::Armenian qw/ arm2int /;
use Convert::Number::Coptic;
# use Convert::Number::Ethiopic; # module is broken
use Convert::Number::Greek qw/ greek2num /;
use Encode qw/ decode /;
use File::Temp ();
use Text::Roman qw/ roman2int /;
use Text::TEI::Markup qw/ to_xml /;
use TryCatch;

BEGIN { extends 'Catalyst::Controller'; }

=encoding utf8

=head1 NAME

ncritic::Controller::MSView - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 msview/index

  GET /msview
  
Returns the index page for this service.

=cut

my $DEFAULT_TEMPLATE = '<?xml version="1.0" encoding="UTF-8"?>
<TEI xmlns="http://www.tei-c.org/ns/1.0">
  <teiHeader>
    <fileDesc>
      <titleStmt>
        <title>__TITLE__</title>
        <author>__AUTHOR__</author>
        <respStmt xml:id="__TRANSCRIBERID__">
          <resp>Transcription by</resp>
          <name>__TRANSCRIBER__</name>
        </respStmt>
      </titleStmt>
      <publicationStmt>
        <p>__PUBLICATIONSTMT__</p>
      </publicationStmt>
      <sourceDesc>
        <msDesc xml:id="__SIGIL__">
          <msIdentifier>
            <repository>__REPOSITORY__</repository>
            <idno>__IDNO__</idno>
          </msIdentifier>
          <p>__PAGES__</p>
        </msDesc>
      </sourceDesc>
    </fileDesc>
  </teiHeader>
  <text>
    <body>
__MAIN__
    </body>
  </text>
</TEI>
';

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->delete_expired_sessions();

	$c->stash->{xmltemplate} ||= $DEFAULT_TEMPLATE;
    $c->stash->{template} = 'msview.tt2';
}

sub reset_all :Local {
	my( $self, $c ) = @_;
	$c->delete_session('user reset request');
	$c->stash->{result} = { xmltemplate => $DEFAULT_TEMPLATE };
	$c->forward('View::JSON');
}

=head2 msview/convert_transcription

  POST msview/convert_transcription,
  { markuptext:	 <Text string to convert to XML>
  	xmltemplate: <XML template string>,
  	language:	 <Language for number conversion> }
  	
URL to request for the conversion to XML. Expects a POST request with the
marked-up text to convert, a template by which to convert it, and a
'language' for any automatic calculation of number values. Recognized
number systems are Greek, Roman, and Armenian.

Returns a JSON response with an HTML snippet for display, the witness sigil, 
the witness identifier, and any extra witness information that should be passed 
through. The XML itself is stored in the local session for up to an hour and
can be retrieved with a call to C<msview/session_xml> (see below).

=cut

sub convert_transcription :Local {
    my( $self, $c ) = @_;
    
	my $tmpl = $c->request->param('xmltemplate'); # TODO b64?
	my $txpn = File::Temp->new();
	my %opts = (
		file => $txpn->filename, 
		template => $tmpl,
		wrap_words => 1 );
	binmode $txpn, ':encoding(UTF-8)';
	print $txpn $c->request->param('markuptext')
		or die "Could not write to temp file $txpn";
	close $txpn;
	my $lang = $c->request->param('language');
	if( $lang ) {
		my $conv_function = sprintf( '_%s_number_value', lc( $lang ) );
		$opts{number_conversion} = \&{$conv_function};
	}

	# Trap and indicate warnings
	my @warnings;
	local $SIG{__WARN__} = sub {
		my $msg = shift;
		$msg =~ s/at (\S+)Markup\.pm.*$//;
		$msg =~ s/\n/ : /g;
		push( @warnings, $msg );
	};
	my $teitext;
    try {
        $teitext = to_xml( %opts );
    } catch( XML::LibXML::Error $e ) {
        $c->stash->{'result'} = { 
        	error_msg => "Could not translate transcription to XML: " . $e->message };
    }
    # We have an XML document, so parse and display it.
	# Display whatever result we got.
	if( $teitext ) {
		# Store the XML itself
		$c->session->{'msview:xmldata'} = $teitext;
		my $ms = $c->model('Transcription');
		$ms->set_xml( $teitext );
		my $textdata = $ms->as_html();
		# Add the XML result back in
		$textdata->{'textcontent'} = $textdata->{'textcontent'};
		$textdata->{'warnings'} = \@warnings;
		$c->stash->{'result'} = $textdata;
	}
	
	$c->forward('View::JSON');
}

=head2 msview/session_xml

  GET msview/session_xml
  
Returns the TEI XML file that was created during the conversion.

=head2 msview/session_json

  GET msview/session_json
  
Returns a tokenized JSON representation of the text that was converted, suitable
for passing to a collation engine such as CollateX or Text::TEI::Collate.

=cut

sub session_xml :Local {
	my( $self, $c ) = @_;
	$self->_parse_session_xml( $c );
	if( $c->stash->{'xmlobj'} ) {
		$c->stash->{'result'} = delete $c->stash->{'xmlobj'};
		$c->stash->{'name'} = 'transcription';
		$c->stash->{'download'} = 1;
		$c->forward('View::TEI');
	} else {
		$c->res->code( 404 );
		$c->stash->{'error_msg'} = 'No transcription found in session';
		$c->stash->{'template'} = 'bareproblem.tt2';
		$c->forward('View::HTML');
	}
}

sub session_json :Local {
	my( $self, $c ) = @_;
	$self->_parse_session_xml( $c );
	$c->stash->{'caller'} = 'session_json';
	$c->forward('_tokenize_xml');
}

=head2 msview/xml_to_json

  POST msview/xml_to_json,
  	(XML file to transform)
  	
Expects an XML document as the body of the request, and returns a JSON-tokenized 
version of a TEI-transcribed manuscript file.
  	
=cut

sub xml_to_json :Local {
	my( $self, $c ) = @_;
	if( $c->req->method eq 'POST' ) {
		$c->session->{'msview:xmldata'} = $self->_get_body_content( $c );
		$self->_parse_session_xml( $c );
		$c->stash->{'caller'} = 'xml_to_json';
		$c->forward('_tokenize_xml');
	} else {
		$c->stash->{'result'} = { error => "Please use POST." };
		$c->forward('View::JSON');
	}
}

sub _parse_session_xml :Private {
	my( $self, $c ) = @_;
	my $parser = XML::LibXML->new();
	return unless exists $c->session->{'msview:xmldata'};
	my $doc = $parser->parse_string( $c->session->{'msview:xmldata'} );
	$c->stash->{'xmlobj'} = $doc;
}

sub _tokenize_xml :Private {
	my( $self, $c ) = @_;
	if( $c->stash->{'xmlobj'} ) {
		# Tokenize the XML using Collate::Manuscript
		my $m = $c->model('Collate');
		my @mss = $m->read_source( $c->stash->{'xmlobj'} );
		if( @mss == 1 ) {
			$c->stash->{'result'} = $mss[0]->tokenize_as_json;
		} else {
			my @wits;
			map { push( @wits, $_->tokenize_as_json ) } @mss;
			$c->stash->{'result'} = { witnesses => \@wits };
		}
	} else {
		$c->res->code( 404 );
		my $error = sprintf( 'No XML found in %s', 
			$c->stash->{'caller'} eq 'session_json' ? 'session' : 'request' );
		$c->stash->{'result'} = { error => $error };
	}
	$c->forward('View::JSON');
}

sub _get_body_content :Private {
	my( $self, $c ) = @_;
	# First, snag the text encoding. Default to UTF-8.
	my $enc = $c->req->content_encoding;
	unless( $enc ) {
		foreach ( $c->req->content_type ) {
			if( $_ =~ /^charset=(\S+)/ ) {
				$enc = $1;
			}
		}
	}
	$enc ||= 'UTF-8';
	# Second, deal with the case of a File::Temp.
	if( ref( $c->req->body ) eq 'File::Temp' ) {
		my $fh = $c->req->body;
		my @lines = <$fh>;
		return( join( '', @lines ) );
	} else {
		return decode( $enc, $c->req->body );
	}
}

=head2 msview/doc

Usage information for the XML conversion / tokenization microservice.

=cut

sub doc :Local {
    my( $self, $c ) = @_;
    $c->stash->{template} = 'transcriberdoc.tt2';
}

sub _roman_number_value {
	my $str = shift;
	return roman2int( $str );
}

sub _greek_number_value {
	my $str = shift;
	return greek2num( $str );
}

sub _armenian_number_value {
    my $str = shift;
	return arm2int( $str );
}

sub _coptic_number_value {
	my $str = shift;
	my $num = Convert::Number::Coptic->new( $str );
	return $num->convert;
}

# sub _ethiopic_number_value {
# 	my $str = shift;
# 	my $num = Convert::Number::Ethiopic->new( $str );
# 	return $num->convert;
# }

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
