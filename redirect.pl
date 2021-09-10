#!perl

use strict;
use warnings;

use Mojolicious::Lite -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);

get '/#asset' => sub ($c) {
  my $ua  = Mojo::UserAgent->new;
  my $res = $ua->get('https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest')->result;
  if ( $res->is_success ) {

    my $asset = $c->param('asset');
    my ( $file, $type ) = split( /\./, $asset );

    my $releases = decode_json( $res->body );

    foreach my $rasset ( @{ $releases->{'assets'} } ) {
      my $rfile = ( split( '/', $rasset->{browser_download_url} ) )[-1];
      if ( $rfile =~ m/\Q$asset/i ) {
        return $c->redirect_to( $rasset->{browser_download_url} );
      }
    }

    if ( defined $type ) {
      foreach my $rasset ( @{ $releases->{'assets'} } ) {
        my $rfile = ( split( '/', $rasset->{browser_download_url} ) )[-1];
        if ( ( defined $type ) and ( $rfile =~ m/\Q$type/i ) ) {
          return $c->redirect_to( $rasset->{browser_download_url} );
        }
      }
    }

    if ( defined $file ) {
      foreach my $rasset ( @{ $releases->{'assets'} } ) {
        my $rfile = ( split( '/', $rasset->{browser_download_url} ) )[-1];
        if ( $rfile =~ m/\Q$file/i ) {
          return $c->redirect_to( $rasset->{browser_download_url} );
        }
      }
    }

    $c->render( text => "No matches found for $asset", status => '200' );
  }
};

get '/*dummy' => { dummy => '' } => sub ($c) {
  my $usage = <<'EOF';
Retrieve the latest ZFSBootMenu assets

# wget, save as the official filename
$ wget --content-disposition https://get.zfsbootmenu.org/efi
$ wget --content-disposition https://get.zfsbootmenu.org/tar.gz
$ wget --content-disposition https://get.zfsbootmenu.org/sha256.sig

# curl, save as the filename passed to get.zfsbootmenu.org
$ curl -O -L https://get.zfsbootmenu.org/zfsbootmenu.EFI
$ curl -O -L https://get.zfsbootmenu.org/zfsbootmenu.tar.gz
$ curl -O -L https://get.zfsbootmenu.org/sha256.sig

Refer to https://github.com/zbm-dev/zfsbootmenu#signature-verification-and-prebuilt-efi-executables

EOF
  return $c->render( text => $usage );
};
app->start;
