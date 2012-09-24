package ncritic::Controller::Collate;
use Encode qw/ encode_utf8 decode_utf8 /;
use JSON::XS qw/ encode_json /;
use Moose;
use namespace::autoclean;
use Text::Tradition;
use Text::Tradition::Collation;
use Text::Tradition::Parser::CollateX;
use TryCatch;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

ncritic::Controller::Root - Controller for ncritic text collation

=head1 DESCRIPTION

A collection of related microservices, each of which exports functionality from the Text::TEI::Collate library. This controller handles actual collation.

=head1 METHODS

=head2 index

The root page (/collate)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->delete_expired_sessions();
    # Set up a new tradition for the session if one doesn't exist
    unless( exists $c->session->{'tradition'} ) {
    	my $t = Text::Tradition->new();
    	$c->session->{'tradition'} = $t;
    }
    # Render the front page
    $c->stash->{template} = 'collation_ui.tt2';	
}

=head2 collate/sendName 

Simple JSON call to set the name of the text we are collating.

=cut

sub setName :Local {
    my ( $self, $c ) = @_;
    # TODO catch a failure
	my $t = $c->session->{'tradition'};
	$t->name( $c->req->params->{'name'} );
    $c->stash->{'result'} = { 'status' => 'ok' };
    $c->forward( 'View::JSON' );
}

=head2 collate/return_texts

Returns a JSON structure with the files and generated or recognized sigla.

JSON structure is:
[ { text: id, title: title, autosigil: sigil }, ... ]

=cut

sub return_texts :Local {
    my( $self, $c ) = @_;
    # TODO think about calling local method 'source' for this
	my $t = $c->session->{'tradition'};
    my $answer = [];
    foreach my $sig ( sort keys %{$c->session->{'sources'}} ) {
        my $textdata = {};
        # Get the manuscripts.   
        my $wit = $t->witness( $sig );
		$textdata->{'text'} = $sig;
		$textdata->{'autosigil'} = $sig;
		my $title = $wit->identifier || 'unidentified ms';
		if( $title =~ /unidentified ms/i ) {
			# Use the filename.
			$title = $c->session->{'sources'}->{$sig}->{'name'};
		}
		$textdata->{'title'} = $title;
        push( @$answer, $textdata );
    }
    $c->stash->{'result'} = $answer;
    $c->forward( 'View::JSON' );
}
    
    

=head2 collate/source

REST interface that handles file upload (and deletion) via the AJAX 
library we are using on client side.  When we POST to this with form data,
it will read in the files, stash them in our model, and then return a JSON 
array of:
 { name: filename
   size: filesize
   url: access URL from text repository
   thumbnail_url: whatever
   delete_url: access URL from text repository
   delete_type: DELETE }
If something goes wrong with parsing the text, we will return an 'errormsg'
key with the problem.
   
GET with a URL argument will return the JSON data for the file requested.
GET with no URL argument will return the JSON data for all files uploaded
in this session.

DELETE with a URL argument will delete all the data associated with the 
specified file that was uploaded.  Returns a JSON status/error message.

=cut

sub source :Local {
    my( $self, $c, $arg ) = @_;
    # Files to upload are in param 'files[]'
    my @answer;
	my $t = $c->session->{'tradition'};
    if( $c->request->method eq 'POST' ) {
        foreach my $field ( $c->request->upload ) {
            my $u = $c->request->upload( $field );
            # Initialize the data return hash
            # TODO Not sure what size is actually used for...
            my $data = { 'name' => $u->filename, 'size' => $u->size };
            # Read in the upload file and pass it to collate's read_source.
            # Judge filetype on the extension
            my $type = $u->filename =~ /xml$/ ? 'xmldesc' : 'plaintext';
            my %opts = ( sourcetype => $type, file => $u->tempname );
            if( $type eq 'plaintext' ) {
            	$opts{sigil} = _generate_autosigil( $c );
            }
            
            my $witness;
            try { 
            	# Try to parse the witness source and throw an error now
            	# if we cannot.
                $witness = $t->add_witness( %opts );
            } catch ( Text::Tradition::Error $err ) {
                # We were not successful.
                # TODO try to say why
                $data->{'errormsg'} = sprintf( "Unable to read text %s from source: %s",
                	$u->filename, $err->message );
                $c->response->code( 500 );
            }
            if( $witness ) {
                # We were successful.
                # TODO make thumbnails for xml vs json vs plaintext sources?
                my $sourceuri = $c->uri_for('source') . '/' . $witness->sigil;
                $data->{'url'} = $sourceuri;
                $data->{'delete_url'} = $sourceuri;
                $data->{'delete_type'} = 'DELETE';
                # Push the complete $data hash onto our return array
                # Save this file data hash into our session
                $c->session->{'sources'}->{$witness->sigil} = $data;
                $c->response->code( 201 );
                $c->response->headers->header( 'Location' => $sourceuri );
            }
            push( @answer, $data );
        }
    } elsif( $c->request->method eq 'GET' ) {
        if( $arg ) {
            # Return the data hash for the requested file.
            my $sourcedata = $c->session->{'sources'}->{$arg};
            if( $sourcedata ) {
                push( @answer, $sourcedata );
            } else {
                push( @answer, { 'errormsg' => "No such uploaded witness ID $arg" } );
            }
        } else {
            # Return the data hash for all files we have in this session.
            my @ids = sort keys %{$c->session->{'sources'}};
            @answer = map { $c->session->{'sources'}->{$_} } @ids;
        }
    } elsif( $c->request->method eq 'DELETE' ) {
    	# Grab the data structure
        my $gone = delete $c->session->{'sources'}->{$arg};
        if( $gone ) {
        	# Delete the witness in question; TODO catch errors?
        	$t->del_witness( $arg );
            push( @answer, { 'status' => "Deleted witness with ID $arg" } );
        } else {
            push( @answer, { 'errormsg' => "No such source $arg" } );
        }
    }
    $c->stash->{'result'} = \@answer;
    $c->forward( 'View::JSON' );
}

sub _generate_autosigil {
	my $c = shift;
	my $last = $c->session->{'autosigil_last'} || 0;
	my $sigil = _get_sigpart( $last );
	$c->session->{'autosigil_last'} = $last + 1;
	return $sigil;
}

sub _get_sigpart {
	my( $idx ) = @_;
	if( $idx < 26 ) {
		return chr( $idx + 65 );
	}
	my $rem = $idx % 26; # the last character
	my $rest = $idx - $rem; # the prior characters, now divisible by 26
	return _get_sigpart( $rest / 26 - 1 ) . _get_sigpart( $rem );
}

## This is the list of output MIME types we recognize, and which 'as_*' 
## function we call in the collator for each one.

my %output_action = (
	'application/xml' => 'TEI',
	'application/json' => 'JSON',
	'application/graphml+xml' => 'GraphML',
	'image/svg+xml' => 'SVG',
	'text/csv' => 'CSV',
	'application/xhtml+xml' => 'HTML',
	'text/html' => 'HTML'
	);

sub output_result :Local {
	my( $self, $c ) = @_;
	
    # Get the format    
    my $format = _restore_format( $c->request->params->{output} );
    $format = $c->request->header( 'Accept' ) unless $format;
	$c->log->debug( "Requested format $format");
	
	## TODO error message for expired session
	my $t = $c->session->{tradition};
	
	# Figure out how to render the manuscripts
	if( $output_action{$format} eq 'HTML' ) {
		# TODO fix this
		$c->stash->{template} = 'collation_bare_html.tt2';
		$c->stash->{mss} = $t->collation->alignment_table;
		$c->forward( 'View::HTML')
			unless $c->request->params->{interactive};
	} else {
		my $action = "as_" . lc( $output_action{$format} );
		my $view = "View::" . $output_action{$format};
		if( $t->collation->can( $action ) ) {
			try {
				$c->stash->{result} = $t->collation->$action();
			} catch( Text::Tradition::Error $e ) {
				$c->log->debug( "Caught error " . $e->message );
				$c->response->code( 500 );
			}
			$c->forward( $view );
		} else {
			$c->stash->{result} = { error => 'Format $format not supported' };
			$c->forward('View::JSON');
		}
	}
    # See if we need to coerce download
	if( $c->request->params->{disposition} eq 'Download' ) {
	    my $ext = lc( $output_action{$format} );
	    $ext = 'xml' if $ext =~ /^(graphml|tei)$/;
	    # Set the Content-Disposition header
	    my $cdisp = "attachment; file=ncritic_collation.$ext";
        $c->response->headers->header( 'Content-Disposition' => $cdisp );
	}

}

=head2 collate/collate_sources

Do the collation on the selected manuscript texts and return the requested
format, as well as a set of actions that can be taken for that format.

=cut

sub collate_sources :Local {
    my( $self, $c ) = @_;

    # Grab the tradition with its mss
    my $answer;
	my $t = $c->session->{tradition};    
    my $collator = $c->model( 'CollateX' );
	my $cxml;
	try {
		# Collate the manuscripts
		$cxml = $collator->collate( $t, 'application/graphml+xml' );
	} catch ( $e ) {
		$answer = { status => 'error', error => $e };
	}
	
	if( $cxml ) {
		try {
			# Save the collation; this will throw on failure
			# $t->_save_collation( Text::Tradition::Collation->new() );
			Text::Tradition::Parser::CollateX::parse( $t, { string => $cxml } );
			$answer = { status => 'OK' };
		} catch ( Text::Tradition::Error $e ) {
			$answer = { 'status' => 'error',
						'error' => $e->message };
		}
	}
    
    # Return the result, hopefully okay  
    $c->stash->{result} = $answer;
    $c->forward( 'View::JSON' );
}

=head1 MICROSERVICE INTERFACE

=head2 collatejson

The bare microservice page (/collate/collatejson)

=cut

sub collatejson :Local {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'collateform.tt2';	
}

=head2 run_collation

The microservice action to run the collation on JSON input (/collate/run_collation)

=cut

sub run_collation :Local {
	my( $self, $c ) = @_;
	# If called interactively, we have params 'display', 'output', 'witnesses'
	# If called non-interactively, we look at headers and content.
	my $json;
	if( $c->request->params->{interactive} ) {
		$json = encode_utf8( $c->request->params->{witnesses} );
	} else {
		# The body is actually a File::Temp object; this is undocumented but 
		# so it seems to be.
		my $fh = $c->request->body;
		my @lines = <$fh>;
		$json = join( '', @lines );
	}
	
    # Get the format    
    my $format = _restore_format( $c->request->params->{output} );
    $format = $c->request->header( 'Accept' ) unless $format;
	$c->log->debug( "Requested format $format");

	# Run the collation on the provided JSON string
	$c->stash->{result} = $c->model('CollateX')->collate( $json, $format );
	# Render the view
	$c->forward( 'View::' . $output_action{$format} );
}

sub _restore_format :Private {
	# Small helper function to get around the inability of form values to 
	# contain a '+' character.
	my $format = shift;
	if( $format eq 'application/graphml'
	    || $format eq 'application/xhtml'
		|| $format eq 'image/svg' ) {
			$format .= '+xml';
	}
	return $format;
}

=head1 UTILITIES ETC.

=head2 collate/doc

Usage information for the tokenization microservice.

=cut

sub doc :Local {
    my( $self, $c ) = @_;
    $c->stash->{template} = 'collatedoc.tt2';
}

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
