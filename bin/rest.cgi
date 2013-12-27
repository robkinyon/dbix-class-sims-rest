#!/usr/bin/env perl
#vi:sw=2

use 5.010_000;

my $CLASS = 'DBIx::Class::Sims::REST';
BEGIN {
  # populate $CLASS or throw an error.
}

use Web::Simple $CLASS;

$CLASS->run_if_script;
