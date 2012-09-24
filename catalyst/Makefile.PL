#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'ncritic';
all_from 'lib/ncritic.pm';

# Outside requirements
requires 'JSON::XS';
requires 'Text::Tradition' => '1.1';

# Moose requirements
requires 'Moose';
requires 'namespace::autoclean';

# Catalyst requirements
requires 'Catalyst::Runtime' => '5.80032';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Model::KiokuDB';
requires 'Catalyst::Model::WebService::CRUST';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store::File';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Unicode::Encoding';
requires 'Catalyst::View::JSON';
requires 'Catalyst::View::TT';
requires 'Config::General'; 

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
