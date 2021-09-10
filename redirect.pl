#!perl

use strict;
use warnings;
use Mojolicious::Lite -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);

get '/#type' => sub ($c) {
  my $ua  = Mojo::UserAgent->new;
  my $res = $ua->get('https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest')->result;
  if ( $res->is_success ) {
    my $releases = decode_json( $res->body );
    my $type     = $c->param('type');
    foreach my $asset ( @{ $releases->{'assets'} } ) {
      if ( $asset->{browser_download_url} =~ m/$type/i ) {
        return $c->redirect_to( $asset->{browser_download_url} );
      }
    }
    $c->render( text => "No matches found" );
  }
};
app->start;
