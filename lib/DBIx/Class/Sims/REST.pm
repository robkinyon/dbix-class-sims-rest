package DBIx::Class::Sims::REST;

use 5.010_000;

our $VERSION = '0.0.1';

use DBI;
use Hash::Merge;
use JSON::XS qw( encode_json decode_json );
use Plack::Request;

our $base_defaults = {
  database => {
    username => '',
    password => '',
    root => {
      username => 'root',
      password => 'root',
    },
  },
  create => 1,
  deploy => 1,
};

sub get_root_connection {
  my $class = shift;
  my ($item, $defaults) = @_;

  my $user = $item->{database}{root}{username} // $defaults->{database}{root}{username};
  my $pass = $item->{database}{root}{password} // $defaults->{database}{root}{password};

  return DBI->connect('dbi:mysql:', $user, $pass);
}

sub get_create_commands {
  my $class = shift;
  my ($item, $defaults) = @_;

  my $user = $item->{database}{username} // $defaults->{database}{username};
  my $pass = $item->{database}{password} // $defaults->{database}{password};
  my $name = $item->{database}{name} // return;

  return (
    "DROP DATABASE IF EXISTS `$name`",
    "CREATE DATABASE `$name`",
    "GRANT ALL ON `$name`.* TO '$user'\@'%' IDENTIFIED BY '$pass'",
  );
}

sub get_schema {
  my $class = shift;
  my ($item, $defaults) = @_;

  my $user = $item->{database}{username} // $defaults->{database}{username};
  my $pass = $item->{database}{password} // $defaults->{database}{password};
  my $name = $item->{database}{name} // return;

  my $schema_class =
    $item->{type} eq 'azure'     ? 'TwoCO::Schema::Azure'     :
    return;

  return $schema_class->connect(
    "dbi:mysql:database=${name}",
    $user, $pass, {
      PrintError => 0,
      RaiseError => 1,
    },
  );
}

sub populate_default_data {
  my $class = shift;
  my ($schema, $item) = @_;

  return;
}

sub do_sims {
  my $class = shift;
  my ($request) = @_;

  my $merger = Hash::Merge->new('RIGHT_PRECEDENT');

  my $defaults = $merger->merge(
    $base_defaults,
    $request->{defaults} // {},
  );

  my $rv = [];
  foreach my $item ( @{$request->{databases} // []} ) {
    my $schema = $class->get_schema($item, $defaults) // next;

    if ( $item->{create} // $defaults->{create} ) {
      my $root_dbh = $class->get_root_connection($item, $defaults) // next;
      my @commands = $class->get_create_commands($item, $defaults) // next;

      $root_dbh->do($_) for @commands;

      # If we create, we have to deploy as well.
      $item->{deploy} = 1;
    }

    # XXX Need to capture the warnings and provide them back to the caller
    if ( $item->{deploy} // $defaults->{deploy} ) {
      $schema->deploy({
        add_drop_table => 1,
        show_warnings => 1,
      });
    }

    $class->populate_default_data($schema, $item);

    push @$rv, $schema->load_sims(
      $item->{spec} // {},
      $item->{options} // {},
    );
  }

  return $rv // { error => 'No actions taken' };
}

sub dispatch_request {
  my $class = shift;
  sub (/sims) {
    sub (POST) {
      my ($self, $env) = @_;
      my $r = Plack::Request->new($env);

      my $request = decode_json($r->content);

      my $rv = $class->do_sims( $request );

      [ 200, [ 'Content-type', 'application/json' ],
        [ encode_json($rv) ],
      ]
    },
  }
}

1;
__END__

=head1 NAME

DBIx::Class::Sims::REST

=head1 SYNOPSIS

In your REST API class:

  package My::Sims::REST

  1;

Then later:

   plackup bin/rest.cgi -p <PORT> -- My::Sims::REST

And, finally, in your test (or some library your tests use):

  my $data = {
      databases => [
          {
              database => {
                  username => 'some username',
                  password => 'some password',
              },
              spec => {
                  <DBIx::Class::Sims specification>
              },
          },
      ],
  };

  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new(POST => 'http://<URL>:<PORT>/sims');
  $req->content(encode_json($data));
  my $res = $ua->request($req);

  return decode_json($res->content);

=head1 PURPOSE

L<DBIx::Class::Sims> provides an easy way to create and populate test data. But,
sometimes, your application isn't built on L<DBIx::Class>. Or Perl. These issues
shouldn't get in the way of using good tools. (Even if your application or test
suite aren't in Perl.)

Assumption: Everything can issue an HTTP request.

Conclusion: The Sims should be available via an HTTP request.

=head1 DESCRIPTION

This is a skeleton base class that provides the basic functionality for a REST
API around L<DBIx::Class::Sims>. By itself, it only takes the request, parses it
out, and invokes a series of methods that have empty implementations. You are
supposed to subclass this class and provide the meat of these methods.

You will have to create a L<DBIx::Class> description of your schema (or, at the
least, the bits you want to be able to sim in your tests). It really isn't that
difficult - there are some examples in the test suite for this module, including
one that uses JSON for the table descriptions. (There are other benefits to
using L<DBIx::Class> to manage your schema, even if your application isn't even
in Perl.)

Once you have all of that, you will need to host this REST API somewhere. Since
its purpose is to aid in testing, a good place for it is in your developers'
Vagrant VMs, and then in the VM you use to run CI tests on.

B<THIS SHOULD NEVER BE MADE AVAILABLE IN PRODUCTION.> If you do so, the problems
you will have are on your head and your head alone. I explicitly and
categorically disavow any and all responsibility for your idiocy if this ends up
in your production environment. Please, do not be stupid.

=head1 METHODS

=head1 TODO

=over 4

* Chef/Puppet recipes for auto-launching the REST API

=back

=head1 BUGS/SUGGESTIONS

This module is hosted on Github at
L<https://github.com/robkinyon/dbix-class-sims>. Pull requests are strongly
encouraged.

=head1 SEE ALSO

L<DBIx::Class::Sims>, L<Web::Simple>

=head1 AUTHOR

Rob Kinyon <rob.kinyon@gmail.com>

=head1 LICENSE

Copyright (c) 2013 Rob Kinyon. All Rights Reserved.
This is free software, you may use it and distribute it under the same terms
as Perl itself.

=cut
