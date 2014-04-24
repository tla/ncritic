package Text::Tradition::WitnessSet::Result::WitnessSet;

use base qw/DBIx::Class::Core/;
__PACKAGE__->table('witness_set');
__PACKAGE__->add_columns(qw/ jobid request_time update_time witnesses algorithm 
	result_format status process result /);
__PACKAGE__->set_primary_key('jobid');

1;