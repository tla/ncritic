package ncritic::Model::CollateX;

use strict;
use base 'Catalyst::Model::WebService::CRUST';
use JSON::XS qw/ encode_json /;

# Create a user agent with the correct headers

sub collate {
	my( $self, $tradition, $return ) = @_;
	
	## Set any UserAgent options that are necessary
	$self->ua->default_header( 'Accept' => $return );
	# TODO timeout?
	
	my $witnessjson;
	if( ref( $tradition ) ) {
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
			push( @$witlist, $struct );
		}
		$witnessjson = encode_json( { 'witnesses' => $witlist } );
	} else { # We were passed a JSON string, not a tradition object.
		$witnessjson = $tradition;
	}
	
	## Post the request and return the result
	$self->post( '/', { -content => $witnessjson } );
	my $result = $self->response;
	if( $result->is_success ) {	
		return $result->content;
	} else {
		# We catch this 'die' in the controller!
		die $result->status_line;
	}
}

__PACKAGE__->config(
	base => 'http://collatex.huygens.knaw.nl',
);

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
