# vi:sw=2
use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Deep;

use Test::Cmd;

use HTTP::Request;
use JSON::XS qw( decode_json encode_json );
use LWP::UserAgent;

my $PORT = 54321;

my $pid = fork;
if ( !defined $pid  || $pid < 0 ) { die "Cannot fork: $!\n"; }

if ( !$pid ) { # Child process
  $ENV{SIMS_CLASS} = 'Test::REST';
  # SIMS_CLASS='Test::REST' plackup -a ../bin/rest.cgi -p $PORT -Ilib -It/lib
  system( "SIMS_CLASS='Test::REST' plackup -a bin/rest.cgi -p $PORT -Ilib -It/lib > /dev/null 2>&1" );
  exit;
}

sleep 1; # Wait for rest.cgi to start

my $data = {
  databases => [
    {
      database => { name => ':memory:' },
      spec => { Artist => [ { name => 'A' } ] },
    },
  ],
};

eval {
  my $req = HTTP::Request->new(POST => "http://localhost:$PORT/sims");
  $req->content(encode_json($data));
  my $res = LWP::UserAgent->new->request($req);
  cmp_deeply decode_json($res->content), [
    {
      Artist => [
        { name => 'A', hat_color => 'purple', id => 1 },
      ]
    },
  ];
}; if ( $@ ) {
  ok 0, "Failed: $@\n";
}

kill 9, $pid, $pid+1, $pid+2;

done_testing;
