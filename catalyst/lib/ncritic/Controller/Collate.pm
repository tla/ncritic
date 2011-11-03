package ncritic::Controller::Collate;
use Encode qw/ encode_utf8 decode_utf8 /;
use JSON qw/ encode_json /;
use Moose;
use namespace::autoclean;
use TryCatch;

BEGIN { extends 'Catalyst::Controller' }

## Service constants
my $TR_LOC = 'http://gregor.middell.net';
my $TR_BASE = '/text-repo/text';


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
    $c->stash->{template} = 'collation_ui.tt2';	
}

=head2 collate/sendName 

Simple JSON call to set the name of the text we are collating.

=cut

sub sendName :Local {
    my ( $self, $c ) = @_;
    my $aligner = $c->model( 'Collate' );
    # TODO catch a failure
    $aligner->title( $c->req->params->{'name'} );
    $c->stash->{'result'} = { 'status' => 'ok' };
    $c->forward( 'View::JSON' );
}

=head2 collate/setLanguage

Simple JSON call to set the language modules to use for the collation of this text.

=cut

sub setLanguage :Local {
    my ( $self, $c ) = @_;
    my $aligner = $c->model( 'Collate' );
    try {
        $aligner->language( $c->req->params->{'language'} );
        $c->stash->{'result'} = { 'status' => 'ok' };
    } catch ( Text::TEI::Collate::Error $e ) {
        $c->stash->{'result'} = { 'error' => $e->message };
        $c->response->code( 500 );
    }
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
    my $answer = [];
    foreach my $id ( sort { $a <=> $b } keys %{$c->session->{'sources'}} ) {
        my $textdata = {};
        # Get the manuscripts.   
        my @mss = @{$c->session->{'sources'}->{$id}->{'mss'}};
        if( @mss == 1 ) {
            $textdata->{'text'} = $id;
            $textdata->{'autosigil'} = $mss[0]->sigil;
            my $title = $mss[0]->identifier;
            if( $title =~ /unidentified ms/i ) {
                # Use the filename.
                $title = $c->session->{'sources'}->{$id}->{'data'}->{'name'};
            }
            $textdata->{'title'} = $title;
        } else {
            # we need to nest texts, hm.
            next;
        }
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
    if( $c->request->method eq 'POST' ) {
        foreach my $field ( $c->request->upload ) {
            my $u = $c->request->upload( $field );
            # Get the sequence number of this file and use it as a key.
            my $key = _create_file_key( $c->session );
            # Read in the upload file and pass it to collate's read_source.
            # TODO Not sure what size is actually used for...
            my $data = { 'name' => $u->filename, 'size' => $u->size };
            my $collator = $c->model( 'Collate' );
            my @manuscripts;
            my $err;
#             try { 
                @manuscripts = $collator->read_source( $u->tempname ); 
#             } catch ( $err ) {
#                 # We were not successful.
#                 # TODO try to say why
#                 $data->{'errormsg'} = "Unable to read texts from source";
#                 $c->response->code( 500 );
#             }
            if( @manuscripts ) {
                # We were successful.
                # TODO make thumbnails for xml vs json vs plaintext sources?
                my $sourceuri = $c->uri_for('source') . "/$key";
                $data->{'url'} = $sourceuri;
                $data->{'delete_url'} = $sourceuri;
                $data->{'delete_type'} = 'DELETE';
                # Push the complete $data hash onto our return array
                # Save this file data into our session
                $c->session->{'sources'}->{$key} = 
                    { 'data' => $data, 'mss' => \@manuscripts };
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
                push( @answer, $sourcedata->{'data'} );
            } else {
                push( @answer, { 'errormsg' => "No such uploaded file ID $arg" } );
            }
        } else {
            # Return the data hash for all files we have in this session.
            my @ids = sort { $a <=> $b } keys %{$c->session->{'sources'}};
            @answer = map { $c->session->{'sources'}->{$_}->{'data'} } @ids;
        }
    } elsif( $c->request->method eq 'DELETE' ) {
        my $gone = delete $c->session->{'sources'}->{$arg};
        if( $gone ) {
            my $numtexts = scalar @{$gone->{'mss'}};
            push( @answer, { 'status' => "Deleted source with $numtexts texts" } );
        } else {
            push( @answer, { 'errormsg' => "No such source $arg" } );
        }
    }
    $c->stash->{'result'} = \@answer;
    $c->forward( 'View::JSON' );
}

sub _create_file_key {
    my $session = shift;
    if( exists $session->{'keymax'} ) {
        $session->{'keymax'} += 1;
    } else {
        $session->{'keymax'} = 0;
    }
    return $session->{'keymax'};
}

# Internal function to run the collation and provide the output.

## This is the list of output MIME types we recognize, and which 'as_*' 
## function we call in the collator for each one.

my %output_action = (
	'application/xml' => 'TEI',
	'application/json' => 'JSON',
	'application/graphml+xml' => 'GraphML',
	'image/svg+xml' => 'SVG',
	'application/xhtml+xml' => 'HTML',
	'text/html' => 'HTML'
	);

sub do_collate :Private {
    my( $self, $c, $manuscripts ) = @_;
    
    # Get the format    
    my $format = _restore_format( $c->request->params->{output} );
    $format = $c->request->header( 'Accept' ) unless $format;
	$c->log->debug( "Requested format $format");
	
	# Collate the manuscripts
    my $collator = $c->model( 'Collate' );
	$collator->align( @$manuscripts );
	
	# Figure out how to render the manuscripts
	if( $output_action{$format} eq 'HTML' ) {
		$c->stash->{template} = 'collation_bare_html.tt2';
		$c->stash->{mss} = $manuscripts;
		$c->forward( 'View::HTML')
			unless $c->request->params->{interactive};
	} else {
		my $action = "to_" . lc( $output_action{$format} );
		my $view = "View::" . $output_action{$format};
		unless( $action ) {
			$c->stash->{error_msg} = 'Format $format not supported';
		}
		$c->stash->{result} = $collator->$action( @$manuscripts );
		$c->forward( $view );
	}
}

=head2 collate/collate_sources

Do the collation and return the requested format. Parameters are text[], sigil_$ID
for each given ID, output.

=cut

sub collate_sources :Local {
    my( $self, $c ) = @_;

    # Grab the mss
    my $manuscripts;
    foreach my $id ( @{$c->request->params->{text}} ) {
        # Set the sigil
        # TODO this assumes one text per ms
        my $sigkey = 'sigil_' . $id;
        my $realsig = $c->request->params->{$sigkey};
        my $ms = $c->session->{'sources'}->{$id}->{'mss'}->[0];
        $ms->sigil( $realsig );
        push( @$manuscripts, $ms );
    }
    # Run the collation
    $c->forward( 'do_collate', [ $manuscripts ] );
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
	
	# Parse out manuscript objects from the JSON
	my $collator = $c->model('Collate');
	my @manuscripts = $collator->read_source( $json );
	$c->log->debug( "Parsed " . scalar( @manuscripts ) . " mss from the JSON");
	
	# Forward to our collator
	$c->forward( 'do_collate', [ \@manuscripts ] );
}

sub _restore_format :Private {
	# Small helper function to get around the inability of form values to 
	# contain a '+' character.
	my $format = shift;
	if( $format eq 'application/graphml'
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
