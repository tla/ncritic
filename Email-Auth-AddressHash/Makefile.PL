#!/usr/bin/perl
use 5.005;
use inc::Module::Install;

author          ('Tara L Andrews <aurum@cpan.org>');
license         ('perl');
all_from        ('lib/Email/Auth/AddressHash.pm');
requires        ('perl' => 5.005);
requires        ('Digest::MD5');
build_requires  ('Test::More');

&WriteAll;
