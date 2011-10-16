use strict;
use warnings;
use Test::More;


use Catalyst::Test 'ncritic';
use ncritic::Controller::Foo;

ok( request('/tokenizetei')->is_success, 'Request should succeed' );
done_testing();
