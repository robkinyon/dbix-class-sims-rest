# vi:sw=2
#use strict;
#use warnings FATAL => 'all';

use Test::More;
#use Test::Deep;
#use Test::Exception;
#use Test::Warn;

BEGIN {
  {
    package MyApp::Schema::Result::Artist;
    use base 'DBIx::Class::Core';
    __PACKAGE__->table('artists');
    __PACKAGE__->add_columns(
      id => {
        data_type => 'int',
        is_nullable => 0,
        is_auto_increment => 1,
      },
      name => {
        data_type => 'varchar',
        size => 128,
        is_nullable => 0,
      },
      hat_color => {
        data_type => 'varchar',
        size => 128,
        is_nullable => 1,
        sim => { value => 'purple' },
      },
    );
    __PACKAGE__->set_primary_key('id');
  }

  {
    package MyApp::Schema;
    use base 'DBIx::Class::Schema';
    __PACKAGE__->register_class(Artist => 'MyApp::Schema::Result::Artist');
    __PACKAGE__->load_components('Sims');
  }

  {
    package MyApp::Sims::REST;
    use DBIx::Class::Sims::REST;
    use base 'DBIx::Class::Sims::REST';
  }
}

use Web::Simple 'MyApp::Sims::REST';
use HTTP::Request;

use Test::DBIx::Class qw(:resultsets);

my $app = MyApp::Sims::REST->new;
sub run_request { $app->run_test_request(@_); }

my $req = HTTP::Request->new( POST => '/sims' );
$req->content_type('application/json');
$req->content('{"json": "here"}');
my $res = run_request($req);
is $res->content, '{"error":"No actions taken"}';

done_testing;
