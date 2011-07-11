#!/usr/bin/perl
use 5.008003;
use inc::Module::Install;
author( 'Tara L Andrews <aurum@cpan.org>' );
license( 'perl' );
all_from( 'lib/Text/TEI/Collate.pm' );
requires( 'perl' => '5.008003' );
requires( 'Algorithm::Diff' );
requires( 'JSON' );
requires( 'Moose' );
requires( 'XML::LibXML' );
recommends( 'Text::WagnerFischer' );
build_requires( 'Text::WagnerFischer::Armenian' );
&WriteAll;
