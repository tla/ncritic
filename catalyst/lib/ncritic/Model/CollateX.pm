package ncritic::Model::CollateX;

use strict;
use warnings;
use Moose;
use JSON::XS qw/ encode_json /;
use LWP::UserAgent;
use Text::Tradition::Parser::CollateX;
use TryCatch;

extends 'Catalyst::Model';

# Create a user agent with the correct headers
has 'ua' => (
	is => 'ro',
	isa => 'LWP::UserAgent',
	default => sub { LWP::UserAgent->new( timeout => 600 ); },
	);
	
has 'url' => (
	is => 'ro',
	isa => 'Str',
	default => 'http://collatex.huygens.knaw.nl/service/collate',
	);
	
=head2 collate( $witnesses, $return_format )

Send the given witnesses out to the CollateX engine, and request results
in the format specified. $witnesses may be either a Text::Tradition object
or an encoded JSON string containing the witnesses. $return_format should
be a MIME type recognized by CollateX.

Returns an array of ( success, message ).

=cut

sub collate {
	my( $self, $tradition, $return ) = @_;
	
	my $witnessjson;
	my $have_object;
	if( ref( $tradition ) ) {
		$have_object = 1;
		## Extract the witnesses in $tradition into JSON format
		my $witlist = [];
		my $layerlabel = $tradition->collation->ac_label;
		foreach my $wit ( $tradition->witnesses ) {
			my $struct = $wit->export_as_json;
			if( exists $struct->{'layertext'} ) {
				# Split it out into a separate witness for now
				my $layertext = delete $struct->{'layertext'};
				push( @$witlist, { 
					id => $wit->sigil . $layerlabel,
					tokens => $layertext } );
			}
			delete $struct->{name}; # TODO restore
			push( @$witlist, $struct );
		}
		# TODO expose collation options on UI page
		$witnessjson = encode_json( { 
			'witnesses' => $witlist, 
			'algorithm' => 'dekker', 
			'joined' => JSON::XS::false } );
	} else { # We were passed a JSON string, not a tradition object.
		$witnessjson = $tradition;
	}
	
	## Post the request and return the result
	my $result = $self->ua->post( $self->url, 
		'Accept' => $return,
		'Content-Type' => 'application/json',
		'Content' => $witnessjson );
	if( $result->is_success ) {
		if( $have_object ) {
			try {
				# Save the collation; this will throw on failure
				Text::Tradition::Parser::CollateX::parse( $tradition, 
					{ string => $result->content } );
				return( 1, 'OK' );
			} catch ( Text::Tradition::Error $e ) {
				return( 0, $e->message );
			} catch {
				return( 0, 'Unexpected CollateX result parse error' );
			}
		} else {
			return( 1, $result->content );
		}
	} else {
		return( 0, $result->status_line );
	}
}

=head1 NAME

ncritic::Model::CollateX - Catalyst WebService::CRUST Model

=head1 SYNOPSIS

See L<ncritic>

=head1 DESCRIPTION

L<Catalyst::Model::WebService::CRUST> Model for making REST queries

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
