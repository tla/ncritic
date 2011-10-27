package ncritic::Model::Collate;

use strict;
use warnings;

use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( class => 'Text::TEI::Collate' );
