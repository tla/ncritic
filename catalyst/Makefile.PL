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
requires 'Text::TEI::Collate';
requires 'Text::TEI::Markup';
requires 'Convert::Number::Armenian';
requires 'Convert::Number::Coptic';
requires 'Convert::Number::Greek';
requires 'Text::Roman';
requires 'TryCatch';
requires 'XML::LibXML';
requires 'XML::LibXML::XPathContext';


# Moose requirements
requires 'Moose';
requires 'namespace::autoclean';

# Catalyst requirements
requires 'Catalyst::Runtime' => '5.80032';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Model::Adaptor';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Session::Store::DBI';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::View::JSON';
requires 'Catalyst::View::TT';
requires 'Config::General'; 

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
