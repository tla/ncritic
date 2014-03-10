use strict;
use warnings;
use Test::More;


use Catalyst::Test 'ncritic';
use ncritic::Controller::MSView;

ok( request('/msview')->is_success, 'Request should succeed' );
done_testing();
