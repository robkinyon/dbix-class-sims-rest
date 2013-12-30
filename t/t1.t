# vi:sw=2
use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Deep;

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
}

use Test::DBIx::Class qw(:resultsets);

BEGIN {
  {
    package MyApp::Sims::REST;
    use DBIx::Class::Sims::REST;
    use base 'DBIx::Class::Sims::REST';

    sub get_schema_class { 'MyApp::Schema' }
    sub get_connect_string { 'dbi:SQLite:dbname=:memory:' }
    sub get_create_commands {}
  }
}

use Web::Simple 'MyApp::Sims::REST';

my $app = MyApp::Sims::REST->new;
sub run_request { $app->run_test_request(@_); }

use HTTP::Request;
use JSON::XS qw( encode_json decode_json );

{
  my $req = HTTP::Request->new( POST => '/sims' );
  $req->content(encode_json( {} ));
  my $res = run_request($req);
  cmp_deeply decode_json($res->content), {
    error => "No actions taken"
  };
}

{
  my $req = HTTP::Request->new( POST => '/sims' );
  $req->content(encode_json({
    databases => [
      {
        database => {
          name => 'foo',
        },
        spec => { Artist => [ { name => 'A'} ] },
      },
    ],
  }));
  my $res = run_request($req);
  cmp_deeply decode_json($res->content), [
    {
      Artist => [
        { name => 'A', hat_color => 'purple', id => 1 },
      ]
    },
  ];
}

done_testing;
