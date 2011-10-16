use strict;
use warnings;
use Test::More;


use Catalyst::Test 'ncritic';
use ncritic::Controller::Foo;

ok( request('/collate')->is_success, 'Request should succeed' );
# TODO tests:
# Test JSON interface
# Test REST AJAX interface
# ... GET without arguments should return all files
# ... GET with argument should return single file
# ... GET with nonexistent arg should return JSON error
# ... POST should return proper JSON array, Location: header, and 201 code
# ... POST with bad source data should fail gracefully
# ... DELETE should return proper JSON answer
# ... DELETE with no args should fail
done_testing();
